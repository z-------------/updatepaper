import docopt
import strutils
import strformat
import streams
import terminal
import os
import asyncdispatch
import sugar
import options
import ./util
import ./versionhistory
import ./updates
import ./client
import ./errorcodes
import ./version

#
# consts
#

const doc = """
Usage:
  updatepaper [-dkRrv] [--build=<BUILD>]
  updatepaper ((-h | --help) | --version)

Options:
  -h --help       Print this help and exit.
  --build=<BUILD> Specify a build number to download.
  -d --dry        Only list updates, without downloading.
  -k --keep       Keep most recent existing jar file with `.old.' infix.
  -R              Ignore state file.
  -r --replace    Rename downloaded jar file, replacing any existing unless -k.
  -v --verbose    Enable verbose output.
  --version       Print program version and exit.
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

let args = docopt(doc, version = "updatepaper " & PkgVersion)

#
# signal handlers
#

setControlCHook() do:
  if isDownloadInProgress:
    writeStream.close()
    try:
      removeFile(filenameTemp.abs)
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
    stderr.write "Couldn't read version history file.\n"

# get new version + builds

let
  updateInfo = getUpdates(currentVersion)
  newerBuilds = updateInfo.builds
  matchingVersion = updateInfo.version
if newerBuilds.len == 0:
  die(MsgNoNewVersion, 2)

# report changes

echo "\n", repeat(' ', 5), "Paper ", matchingVersion, "\n"
# for build in newerBuilds:
#   let formatted = build.format(args["--verbose"])
#   if formatted.strip.len > 0:
#     echo formatted

# download new build

if args["--dry"]:
  quit()

let
  chosenBuildArg = $args["--build"]
  chosenBuildNumber =
    if chosenBuildArg != "nil":
      chosenBuildArg.parseInt
    else:
      -1
  chosenBuild =
    if chosenBuildNumber != -1:
      block:
        let maybeChosenBuild = newerBuilds.filterOne(build => build.number == chosenBuildNumber)
        if maybeChosenBuild.isNone:
          die($"Build #{chosenBuildNumber} not found.")
        else:
          maybeChosenBuild.get
    else:
      newerBuilds[0]
  url = chosenBuild.downloadUrl
  buildNumber = chosenBuild.number
  filename = &"paper-{buildNumber}.jar"

filenameTemp = filename & ".temp"

echo &"Downloading {matchingVersion} #{pad(buildNumber, 3)}..."
logVerbose &"Writing to {filenameTemp}...";

isDownloadInProgress = true

try:
  writeStream = openFileStream(filenameTemp.abs, fmWrite)
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
    moveFile(filename.abs, (&"paper-{buildNumber}.old.jar").abs)
    logVerbose "Renamed old numbered jar to paper-{buildNumber}.old.jar."
  except OSError:
    if osLastError().isEnoent:
      logVerbose "No old numbered jar to rename. Continuing."
    else:
      die &"Couldn't rename {filename}."

# rename to paper-xxx.jar, removing .temp suffix
try:
  moveFile(filenameTemp.abs, filename.abs)
  logVerbose &"Renamed {filenameTemp} to {filename}."
except OSError:
  die &"Couldn't rename {filenameTemp}."

if args["--replace"]:  # rename to paper.jar
  # move any existing paper.jar to paper.temp.jar
  try:
    if moveFileOptional("paper.jar".abs, "paper.temp.jar".abs):
      logVerbose("Renamed old jar to paper.temp.jar.")
  except:
    die "Couldn't rename paper.jar."
  
  try:
    moveFile(filename.abs, "paper.jar".abs)
    logVerbose "Renamed new jar."
  except:
    die &"Couldn't rename {filename}."
  
  if args["--keep"]:  # keep any old paper.jar (now renamed paper.temp.jar)
    try:
      if moveFileOptional("paper.temp.jar".abs, "paper.old.jar".abs):
        logVerbose "Renamed temp jar to paper.old.jar."
    except:
      die "Couldn't rename paper.temp.jar."
  else:  # delete any old paper.jar (now renamed paper.temp.jar)
    try:
      if removeFileOptional("paper.temp.jar".abs):
        logVerbose "Deleted temp jar."
    except:
      die "Couldn't delete paper.temp.jar."
