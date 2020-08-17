import docopt
import strutils
import strformat
import ./util
import ./versionhistory
import ./matchversion
import ./builds

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

let currentVersion = readVersionHistoryFile()
let matchingVersion = getMatchingVersion(currentVersion.apiVer)
if matchingVersion == "":
  die(MsgNoNewVersion, 2)

let newerBuilds = getNewerBuilds(matchingVersion.semverGetMajor, currentVersion.buildNum)
if newerBuilds.len == 0:
  die(MsgNoNewVersion, 2)

echo "\n", repeat(' ', 5), "Paper ", matchingVersion, "\n"
for build in newerBuilds:
  let formatted = formatBuildInfo(build, isVerbose)
  if formatted.strip.len > 0:
    echo formatted

if isDry:
  quit()

let buildNumber =
  if args.hasKey("--build"): $args["--build"]
  else: $newerBuilds[0].number
let
  url = &"https://papermc.io/api/v1/paper/{matchingVersion}/{buildNumber}/download"
  filename = &"paper-{buildNumber}.jar"
  filenameTemp = filename & ".temp";

echo &"Downloading {matchingVersion} {pad(buildNumber, 3)}..."
