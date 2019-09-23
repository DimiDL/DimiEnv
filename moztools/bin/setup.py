#!/usr/bin/env python2

import os
import signal
import subprocess
import sys
import re

HOME = os.path.expanduser("~")
MOZ_BUILD = HOME + "/.mozbuild"
DIMI_TOOLS = HOME + '/.dimitools'

def run_process(cmds):
    for cmd in cmds:
        l = re.compile("[ ](?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)").split(cmd)
        print l
        proc = subprocess.Popen(l)

        # ignore SIGINT, the mozlint subprocess should exit quickly and gracefully
        orig_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
        proc.wait()
        signal.signal(signal.SIGINT, orig_handler)
    # return proc.returncode

def verify_mozbuild():
    HOME = os.path.expanduser("~") + "/.mozbuild"
    mozbuild = HOME + "/.mozbuild"

    ret = os.path.exists(mozbuild)
    print ("[OK]" if ret else "[FAIL]") + " Verify " + mozbuild

def verify_and_chdir(directory):
    if not verify_directory(directory):
        return False
    os.chdir(directory)
    return True

def verify_directory(directory):
    return os.path.exists(directory)

def setup_gitbz():
    if not verify_and_chdir(MOZ_BUILD):
        print "[Fail] Setup gitbz"

    if verify_directory(MOZ_BUILD + "/git-bz-moz"):
        print "[Ok] gitbz already exists"
    else:
        cmds = ["git clone https://github.com/mozilla/git-bz-moz"]
        run_process(cmds)

    cmds = [
        "git config --global bz.username dimi",
        "git config --global bz.default-tracker bugzilla.mozilla.org",
        "git config --global bz.default-product Toolkit",
        "git config --global bz.default-component \"Safe Browsing\""]
    run_process(cmds)

    link = MOZ_BUILD + "/git-bz-moz" + "/git-bz"
    cmds = [
        "ln -s " + link + " /usr/local/bin/git-bz"
    ]
    run_process(cmds)

    path = DIMI_TOOLS + "/api" + "/git-bz.api"
    if verify_directory(path):
        f = open(path, "r")
        api = f.readline().rstrip()
    else:
        print '[Fail] No git-bz API key'
        return

    cmds = [
        "git config --global bz.apikey " + api]
    run_process(cmds)

    print "[Ok] gitbz setuped"

def parse_argument(args):
    return

if __name__ == '__main__':
    parse_argument(sys.argv)

    setup_gitbz()
