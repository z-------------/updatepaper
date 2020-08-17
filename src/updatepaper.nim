import docopt
import strutils
import strformat
import streams
import terminal
import ./util
import ./versionhistory
import ./matchversion
import ./builds
import ./client

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
# main
#

let
  args = docopt(doc)

  isVerbose = args["--verbose"]
  isDry = args["--dry"]

  log = getLogger(isVerbose)

var isDownloadInProgress = false

# get matching major

let currentVersion = readVersionHistoryFile()
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

if isDry:
  quit()

let buildNumber =
  if $args["--build"] != "nil": $args["--build"]
  else: $newerBuilds[0].number
let
  url = &"https://papermc.io/api/v1/paper/{matchingVersion}/{buildNumber}/download"
  filename = &"paper-{buildNumber}.jar"
  filenameTemp = filename & ".temp"

echo &"Downloading {matchingVersion} {pad(buildNumber, 3)}..."
log &"Writing to {filenameTemp}...";

isDownloadInProgress = true

const BufLen = 1 shl 10  # 1024
var
  buf: array[BufLen, char]
  bytesRead = 0
  writeStream: FileStream
let
  bufPtr = buf.addr
  response = client().get(url)
  contentLength = response.headers["Content-Length"].parseInt
  readStream = response.bodyStream

try:
  writeStream = openFileStream(filenameTemp.rel, fmWrite)
except IOError:
  die "Failed to open write stream."

while not readStream.atEnd:
  bytesRead += readStream.readData(bufPtr, BufLen)
  writeStream.writeData(bufPtr, BufLen)
  stdout.write "\r", progressBar(bytesRead / contentLength, terminalWidth())

isDownloadInProgress = false
echo "Download complete."

# TODO: the rest
