#!/usr/bin/env python

from __future__ import print_function
import sys
import os
import zlib
import binascii
import operator
import sqlite3
import struct

import argparse

# File format of .sbstore files:
#
# We do not store the add prefixes, those are retrieved by
# decompressing the PrefixSet cache whenever we need to apply
# an update.
#
# byte slicing: Many of the 4-byte values stored here are strongly
# correlated in the upper bytes, and uncorrelated in the lower
# bytes. Because zlib/DEFLATE requires match lengths of at least
# 3 to achieve good compression, and we don't get those if only
# the upper 16-bits are correlated, it is worthwhile to slice 32-bit
# values into 4 1-byte slices and compress the slices individually.
# The slices corresponding to MSBs will compress very well, and the
# slice corresponding to LSB almost nothing. Because of this, we
# only apply DEFLATE to the 3 most significant bytes, and store the
# LSB uncompressed.
#
# byte sliced (numValues) data format:
#    uint32 compressed-size
#    compressed-size bytes    zlib DEFLATE data
#        0...numValues        byte MSB of 4-byte numValues data
#    uint32 compressed-size
#    compressed-size bytes    zlib DEFLATE data
#        0...numValues        byte 2nd byte of 4-byte numValues data
#    uint32 compressed-size
#    compressed-size bytes    zlib DEFLATE data
#        0...numValues        byte 3rd byte of 4-byte numValues data
#    0...numValues            byte LSB of 4-byte numValues data
#
# Store data format:
#    uint32 magic
#    uint32 version
#    uint32 numAddChunks
#    uint32 numSubChunks
#    uint32 numAddPrefixes
#    uint32 numSubPrefixes
#    uint32 numAddCompletes
#    uint32 numSubCompletes
#    0...numAddChunks               uint32 addChunk
#    0...numSubChunks               uint32 subChunk
#    byte sliced (numAddPrefixes)   uint32 add chunk of AddPrefixes
#    byte sliced (numSubPrefixes)   uint32 add chunk of SubPrefixes
#    byte sliced (numSubPrefixes)   uint32 sub chunk of SubPrefixes
#    byte sliced (numSubPrefixes)   uint32 SubPrefixes
#    0...numAddCompletes            32-byte Completions + uint32 addChunk
#    0...numSubCompletes            32-byte Completions + uint32 addChunk + uint32 subChunk
#    16-byte MD5 of all preceding data

class SBHash:
    def __init__(self, prefix=None, addc=None, subc=None):
        self.prefix = prefix
        self.addchunk = addc
        self.subchunk = subc
    def __str__(self):
        if self.subchunk:
            result = "Prefix %X AddChunk: %d SubChunk: %d" \
                      % (self.prefix, self.addchunk, self.subchunk)
        else:
            result = "Prefix %X AddChunk: %d" % (self.prefix, self.addchunk)
        return result
    def __key(self):
        return self.prefix, self.addchunk, self.subchunk
    def __eq__(self, other):
        return self.__key() == other.__key()
    def __hash__(self):
        return hash(self.__key())

class SBData:
    def __init__(self):
        self.name = None
        self.addchunks = set()
        self.fake_add_chunks = set()
        self.subchunks = set()
        self.addprefixes = []
        self.subprefixes = []
        self.addcompletes = []
        self.subcompletes = []
    def add_addchunk(self, chunk):
        self.addchunks.add(chunk)
    def add_subchunk(self, chunk):
        self.subchunks.add(chunk)
    def fill_addprefixes(self, prefixes):
        """Add prefixes are stored in the PrefixSet instead of in the sbstore,
        so allow filling them in seperately afterwards."""
        assert len(prefixes) == len(self.addprefixes), \
               "Prefixes: %d AddPrefixes: %d" \
               % (len(prefixes), len(self.addprefixes))
        for i, pref in enumerate(self.addprefixes):
            pref.prefix = prefixes[i]
    def sort_all_data(self):
        self.addprefixes.sort(
            key=operator.attrgetter('prefix', 'addchunk'))
        self.subprefixes.sort(
            key=operator.attrgetter('prefix', 'subchunk', 'addchunk'))
        self.addcompletes.sort(
            key=operator.attrgetter('prefix', 'addchunk'))
        self.subcompletes.sort(
            key=operator.attrgetter('prefix', 'subchunk', 'addchunk'))

def read_unzip(fp, comp_size):
    """Read comp_size bytes from a zlib stream and
     return as a tuple of bytes"""
    zlib_data = fp.read(comp_size)
    uncomp_data = zlib.decompress(zlib_data)
    bytebuffer = struct.Struct("=" + str(len(uncomp_data)) + "B")
    data = bytebuffer.unpack_from(uncomp_data, 0)
    return data

def read_raw(fp, size):
    """Read raw bytes from a stream and return as a tuple of bytes"""
    bytebuffer = struct.Struct("=" + str(size) + "B")
    data = bytebuffer.unpack_from(fp.read(size), 0)
    return data

def readuint32(fp):
    uint32 = struct.Struct("=I")
    return uint32.unpack_from(fp.read(uint32.size), 0)[0]

def readuint16(fp):
    uint16 = struct.Struct("=H")
    return uint16.unpack_from(fp.read(uint16.size), 0)[0]

def read_bytesliced(fp, count):
    comp_size = readuint32(fp)
    slice1 = read_unzip(fp, comp_size)
    comp_size = readuint32(fp)
    slice2 = read_unzip(fp, comp_size)
    comp_size = readuint32(fp)
    slice3 = read_unzip(fp, comp_size)
    slice4 = read_raw(fp, count)

    if (len(slice1) != len(slice2)) or \
       (len(slice2) != len(slice3)) or \
       (len(slice3) != len(slice4)) or \
       (count       != len(slice1)):
        print("Slices inconsistent %d %d %d %d %d"
            % (count, len(slice1), len(slice2), len(slice3), len(slice4)))
        exit(1)

    result = []
    for i in range(count):
        val = (slice1[i] << 24) | (slice2[i] << 16) \
            | (slice3[i] << 8) | slice4[i]
        result.append(val)
    return result

def read_sbstore(sbstorefile, sbstorename, verbose):
    data = SBData()
    fp = open(sbstorefile, "rb")

    # parse header (32 (8 x 4) bytes)
    header = struct.Struct("=IIIIIIII")
    magic, version, num_add_chunk, num_sub_chunk, \
    num_add_prefix, num_sub_prefix, \
    num_add_complete, num_sub_complete = header.unpack_from(fp.read(header.size), 0)
    print(("[%s] Magic %X Version %u NumAddChunk: %d NumSubChunk: %d "
           + "NumAddPrefix: %d NumSubPrefix: %d NumAddComplete: %d "
           + "NumSubComplete: %d") % (sbstorename, 
                                      magic, version, num_add_chunk,
                                      num_sub_chunk, num_add_prefix,
                                      num_sub_prefix, num_add_complete,
                                      num_sub_complete))

    # parse add/sub chunk numbers
    verbose and print("[%s] AddChunks: " % (sbstorename), end="");
    for x in range(num_add_chunk):
        chunk = readuint32(fp)
        data.add_addchunk(chunk)
        verbose and print("%d" % chunk, end="");
        if x != num_add_chunk - 1:
          verbose and print(",", end="");
    verbose and print("");
    verbose and print("[%s] SubChunks: " % (sbstorename), end="");
    for x in range(num_sub_chunk):
        chunk = readuint32(fp)
        data.add_subchunk(chunk)
        verbose and print("%d" % chunk, end="");
        if x != num_sub_chunk - 1:
          verbose and print(",", end="");
    verbose and print("");

    # read bytesliced data
    addprefix_addchunk = read_bytesliced(fp, num_add_prefix)
    subprefix_addchunk = read_bytesliced(fp, num_sub_prefix)
    subprefix_subchunk = read_bytesliced(fp, num_sub_prefix)
    subprefixes        = read_bytesliced(fp, num_sub_prefix)

    # Construct the prefix objects
    for i in range(num_add_prefix):
        prefix = SBHash(0, addprefix_addchunk[i])
        data.addprefixes.append(prefix)
    for i in range(num_sub_prefix):
        prefix = SBHash(subprefixes[i],
                        subprefix_addchunk[i],
                        subprefix_subchunk[i])
        data.subprefixes.append(prefix)
        # print sub hash prefixes
        verbose and print("[%s] subPrefix[chunk:%d] " % (
          sbstorename, subprefix_subchunk[i]), end="");
        verbose and print("%02x" % ((subprefixes[i] & (0xFF << 24)) >> 24), end="");
        verbose and print("%02x" % ((subprefixes[i] & (0xFF << 16)) >> 16), end="");
        verbose and print("%02x" % ((subprefixes[i] & (0xFF <<  8)) >>  8), end="");
        verbose and print("%02x" % ((subprefixes[i] & (0xFF <<  0)) >>  0), end="");
        verbose and print("");
    for x in range(num_add_complete):
        complete = read_raw(fp, 32)
        addchunk = readuint32(fp)
        # print add complete hashes
        verbose and print("[%s] addComplete[chunk:%d] " % (
          sbstorename, addchunk), end="");
        for byte in complete:
          verbose and print("%02x" % (byte), end="");
        verbose and print("");
        #
        entry = SBHash(complete, addchunk)
        data.addcompletes.append(entry)
    for x in range(num_sub_complete):
        complete = read_raw(fp, 32)
        addchunk = readuint32(fp)
        subchunk = readuint32(fp)
        # print sub complete hashes
        print("[%s] subComplete[chunk:%d]: " % (
          sbstorename, subchunk), end="");
        for byte in complete:
          print("%02x" % (byte), end="");
        print("");
        entry = SBHash(complete, addchunk, subchunk)
        data.subcompletes.append(entry)
    md5sum = fp.read(16)
    print(("[%s] MD5: " + binascii.b2a_hex(md5sum)) % (sbstorename))
    # EOF detection
    dummy = fp.read(1)
    if len(dummy) or (len(md5sum) != 16):
        if len(md5sum) != 16:
            print("Checksum truncated")
        print("File doesn't end where expected:", end=" ")
        # Don't count the dummy read, we finished before it
        ourpos = fp.tell() - len(dummy)
        # Seek to end
        fp.seek(0, 2)
        endpos = fp.tell()
        print("%d bytes remaining" % (endpos - ourpos))
        exit(1)
    return data

def pset_to_prefixes(index_prefixes, index_starts, index_deltas):
    prefixes = []
    prefix_len = len(index_prefixes)
    for i in range(prefix_len):
        prefix = index_prefixes[i]
        prefixes.append(prefix)
        start = index_starts[i]
        if i != (prefix_len - 1):
            end = index_starts[i + 1]
        else:
            end = len(index_deltas)
        #print("s: %d e: %d" % (start, end))
        for j in range(start, end):
            #print("%d " % index_deltas[j])
            prefix += index_deltas[j]
            prefixes.append(prefix)
    return prefixes

def read_pset(filename):
    fp = open(filename, "rb")
    version = readuint32(fp)
    indexsize = readuint32(fp)
    deltasize = readuint32(fp)
    #print("Version: %X Indexes: %d Deltas: %d" % (
    #  version, indexsize, deltasize))
    index_prefixes = []
    index_starts = []
    index_deltas = []
    for x in range(indexsize):
        index_prefixes.append(readuint32(fp))
    for x in range(indexsize):
        index_starts.append(readuint32(fp))
    for x in range(deltasize):
        index_deltas.append(readuint16(fp))
    prefixes = pset_to_prefixes(index_prefixes, index_starts, index_deltas)
    # empty set has a special form
    if len(prefixes) and prefixes[0] == 0:
        prefixes = []
    return prefixes

def parse_databases(dir, verbose, name, dry):
    # look for all sbstore files
    sb_lists = {}
    for file in os.listdir(dir):
        if file.endswith(".sbstore"):
            sb_file = os.path.join(dir, file)
            sb_name = file[:-len(".sbstore")]
            if name != '' and name != sb_name:
              continue;
            print("- Reading sbstore: " + sb_name)
            if dry:
              continue;
            sb_data = read_sbstore(sb_file, sb_name, verbose);
            prefixes = read_pset(os.path.join(dir, sb_name + ".pset"))
            sb_data.name = sb_name
            sb_data.fill_addprefixes(prefixes)
            # print add hash prefixes
            for addprefix in sb_data.addprefixes:
              verbose and print("[%s] addPrefix[chunk:%d] " % (
                sb_name, addprefix.addchunk), end="");
              verbose and print("%02x" % ((addprefix.prefix & (0xFF << 24)) >> 24), end="");
              verbose and print("%02x" % ((addprefix.prefix & (0xFF << 16)) >> 16), end="");
              verbose and print("%02x" % ((addprefix.prefix & (0xFF <<  8)) >>  8), end="");
              verbose and print("%02x" % ((addprefix.prefix & (0xFF <<  0)) >>  0), end="");
              verbose and print("");
            sb_data.sort_all_data()
            sb_lists[sb_name] = sb_data
            print("\n")
    # print list names found
    #for name in sb_lists.keys():
    #    print("- Found list: %s" % name)
    #return sb_lists

def main(argv):

    parser \
      = argparse.ArgumentParser(
         description='Dump Firefox SafeBrowsing database files.')

    parser.add_argument('--verbose', '-v', 
      action='store_const', const=True, default=False, 
      help='list database contents (prefixes/completes) in hex');

    parser.add_argument('--dry', '-n', 
      action='store_const', const=True, default=False, 
      help='dry run. list available databases and quit');

    parser.add_argument('--name', nargs='?', default='', 
      help='process only list named NAME');

    parser.add_argument('sbstore_dir', nargs=1, 
      help='directory with safebrowsing database files. (.sbstore, .pset) Should be called \'safebrowsing\' under a Firefox profile directory');

    args = parser.parse_args();

    sbstore_dir = args.sbstore_dir[0];
    parse_databases(sbstore_dir, args.verbose, args.name, args.dry);

if __name__ == "__main__":

    main(sys.argv)
