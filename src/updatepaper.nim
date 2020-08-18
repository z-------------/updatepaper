import docopt
import strutils
import strformat
import streams
import terminal
import os
import asyncdispatch
import ./util
import ./versionhistory
import ./matchversion
import ./builds
import ./client
import ./errorcodes

#
# consts
#

const doc = """
Usage:
  updatepaper [-dkRrv] [--build=<BUILD>]
  updatepaper (-h | --help)

Options:
  -h --help       Show this help and exit.
  --build=<BUILD> Specify a build number to download.
  -d --dry        Only list updates, without downloading.
  -k --keep       Keep most recent existing jar file with `.old.' infix.
  -R              Ignore state file.
  -r --replace    Rename downloaded jar file, replacing any existing unless -k.
  -v --verbose    Enable verbose output.
"""

const MsgNoNewVersion = "No matching new version available."

#
# globals
#

var # needed by SIGINT (Ctrl-C) handler
  isDownloadInProgress = false
  filenameTemp: string
  writeStream: FileStream

#
# parse options
#

let
  args = docopt(doc)
  isVerbose = args["--verbose"]
  logVerbose = getLogger(isVerbose)

#
# signal handlers
#

setControlCHook() do:
  if isDownloadInProgress:
    writeStream.close()
    try:
      removeFile(filenameTemp.rel)
      logVerbose &"Deleted {filenameTemp}."
    except:
      die &"Failed to delete {filenameTemp}."
  quit()

#
# main
#

var currentVersion: CurrentVersion = (apiVer: "", buildNum: -1)
if not args["-R"]:
  try:
    currentVersion = readVersionHistoryFile()
  except:
    stderr.write "Couldn't read version history file."

# get matching major

let matchingVersion = getMatchingVersion(currentVersion.apiVer)
if matchingVersion == "":
  die(MsgNoNewVersion, 2)

# get new builds

let newerBuilds = getNewerBuilds(matchingVersion.semverGetMajor, currentVersion.buildNum)
if newerBuilds.len == 0:
  die(MsgNoNewVersion, 2)

# report changes

echo "\n", repeat(' ', 5), "Paper ", matchingVersion, "\n"
for build in newerBuilds:
  let formatted = formatBuildInfo(build, isVerbose)
  if formatted.strip.len > 0:
    echo formatted

# download new build

if args["--dry"]:
  quit()

let buildNumber =
  if $args["--build"] != "nil": $args["--build"]
  else: $newerBuilds[0].number
let
  url = &"https://papermc.io/api/v1/paper/{matchingVersion}/{buildNumber}/download"
  filename = &"paper-{buildNumber}.jar"
filenameTemp = filename & ".temp"

echo &"Downloading {matchingVersion} #{pad(buildNumber, 3)}..."
logVerbose &"Writing to {filenameTemp}...";

isDownloadInProgress = true

try:
  writeStream = openFileStream(filenameTemp.rel, fmWrite)
except IOError:
  die "Couldn't open write stream."

waitFor (proc () {.async.} =
  try:
    let
      response = await asyncClient().get(url)
      contentLength = response.contentLength
      readStream = response.bodyStream
    var bytesRead = 0

    while true:
      let (hasMore, data) = await readStream.read()
      bytesRead += data.len
      writeStream.write(data)
      stdout.write "\r", progressBar(bytesRead / contentLength, terminalWidth())
      if not hasMore:
        break

    writeStream.close()
    isDownloadInProgress = false
    echo "Download complete."
  except:
    die "Error downloading."
)()

if args["--keep"]:  # keep any old paper-xxx.jar with same build number
  try:
    moveFile(filename.rel, (&"paper-{buildNumber}.old.jar").rel)
    logVerbose "Renamed old numbered jar to paper-{buildNumber}.old.jar."
  except OSError:
    if osLastError().isEnoent:
      logVerbose "No old numbered jar to rename. Continuing."
    else:
      die &"Couldn't rename {filename}."

# rename to paper-xxx.jar, removing .temp suffix
try:
  moveFile(filenameTemp.rel, filename.rel)
  logVerbose &"Renamed {filenameTemp} to {filename}."
except OSError:
  die &"Couldn't rename {filenameTemp}."

if args["--replace"]:  # rename to paper.jar
  # move any existing paper.jar to paper.temp.jar
  try:
    moveFileOptional("paper.jar".rel, "paper.temp.jar".rel)
    logVerbose("Renamed old jar (if it exists) to paper.temp.jar.")
  except:
    die "Couldn't rename paper.jar."
  
  try:
    moveFile(filename.rel, "paper.jar".rel)
    logVerbose "Renamed new jar."
  except:
    die &"Couldn't rename {filename}."
  
  if args["--keep"]:  # keep any old paper.jar (now renamed paper.temp.jar)
    try:
      moveFileOptional("paper.temp.jar".rel, "paper.old.jar".rel)
      logVerbose "Renamed temp jar (if it exists) to paper.old.jar."
    except:
      die "Couldn't rename paper.temp.jar."
  else:  # delete any old paper.jar (now renamed paper.temp.jar)
    try:
      removeFileOptional("paper.temp.jar".rel)
      logVerbose "Deleted temp jar (if it exists)."
    except:
      die "Couldn't delete paper.temp.jar."
