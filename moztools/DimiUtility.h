#define DDLOG(args) printf_stderr args
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#ifndef DimiUtility_h__
#define DimiUtility_h__

// Dimi's Always print message
#ifndef DMLOG
#define DMLOG(args)   \
  printf_stderr(args);  \
  printf_stderr("\n");

#define DDLOG(args) printf_stderr args
//#define DM_FENTRY() DMLOG("[Dimi]%s >>", __FUNCTION__)
//#define DM_FEXIT()  DMLOG("[Dimi]%s <<", __FUNCTION__)

function getStackDump() {
  var lines = [];
  for (var frame = Components.stack; frame; frame = frame.caller) {
    lines.push(frame.filename + " (" + frame.lineNumber + ")");
  }
  return lines.join("\n");
}

// begin of the utility anonymous namespace
namespace {

nsCString UriToString(nsIURI* aURI)
{
  nsCString s;
  if (aURI)
    aURI->GetAsciiSpec(s);
  return s;
}

nsCString ChToString(nsIChannel* aChannel)
{
  nsCString s;
  if (aChannel) {
    nsCOMPtr<nsIURI> uri;
    aChannel->GetURI(getter_AddRefs(uri));
    if (uri) {
      uri->GetAsciiSpec(s);
    }
  }
  return s;
}

// Somehow this doesn't work
// static const char* FileToString(nsIFile* aFile) {
//   return FielToString(aFile).get()
// }
static nsCString FileToString(nsIFile* aFile)
{
  nsCString s;

  if (aFile) {
#ifdef WIN32
    nsAutoCString path, name;
    aFile->GetNativePath(path);
    aFile->GetNativeLeafName(name);
    s.AppendPrintf("%s/%s", path.get(), name.get());
#else
    aFile->GetNativePath(s);
#endif
  }
  return s;
}


template <typename T>
nsresult DumpValue(T& aValue) {
  LOG(("[Dimi]%s : ", __func__))
}

} // end of the utility anonymous namespace

#endif

//TODO: 1. Remove (())
//      2. Add \n In the end
//      3. Add function >>, <<
//      4. Add break point inside function

#endif
