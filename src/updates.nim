import json
import times
import strformat
import strutils
import nre
import ./client
import ./util
import ./versionhistory

const DownloadsIndexUrl = "https://papermc.io/js/downloads.js"

type
  ChangeItem* = ref object
    comment*: string
    id*: string
  Build* = ref object
    number*: int
    date*: DateTime
    changeSet*: seq[ChangeItem]
  Updates* = ref object
    version*: string
    builds*: seq[Build]

#
# helpers
#

proc semverGetMajor*(v: string): string =
  v.split(".")[0..1].join(".")

proc semverSplit*(v: string): seq[int] =
  for part in v.split("."):
    result.add(parseInt(part))

proc semverEq*(verA, verB: string; n = 3): bool =
  if verA.len == 0:
    return true
  let
    splitA = verA.semverSplit
    splitB = verB.semverSplit
  for i in 0..<n:
    if splitA[i] != splitB[i]:
      return false
  return true

proc buildNumberGt*(bnA, bnB: int): bool =
  bnA == -1 or bnB > bnA

proc buildUrl(majorVer: string): string =
  &"https://papermc.io/ci/job/Paper-{majorVer}/api/json?tree=builds[number,timestamp,changeSet[items[comment,commitId,msg]]]"

proc getDownloadsIndex(): JsonNode =
  ## Fetch and parse the JSON table of downloadables.
  let data = client().getContent(DownloadsIndexUrl)
  var
    openCount = 0
    closeCount = 0
    startIdx = -1
    endIdx = -1
  for i in 0..high(data):
    let c = data[i]
    if c == '{':
      openCount.inc
      if startIdx == -1:
        startIdx = i
    elif c == '}':
      closeCount.inc
    if openCount > 1 and openCount == closeCount:
      endIdx = i + 1
      let sub = data[startIdx..<endIdx]
        .replace(re"\/\/.*", "")    # remove comments
        .replace(re",\s*(?=})", "") # remove trailing comma
      return parseJson(sub)

proc getMatchingVersion(currentApiVer: string): string =
  ## Given the current Paper version and a table of available downloads,
  ## find the matching available version.
  let downloads = getDownloadsIndex() 
  for key in downloads.keys:
    let
      node = downloads[key]
      endpointName = node["api_endpoint"].getStr
      apiVer = node["api_version"].getStr
    if endpointName == "paper" and semverEq(currentApiVer, apiVer, 2):
      return apiVer

proc getNewBuilds(majorVersion: string; currentBuildNumber: int): seq[Build] =
  let
    data = client().getContent(buildUrl(majorVersion))
    buildsJson = parseJson(data)["builds"]

  for buildNode in buildsJson.elems:
    var
      build = Build()
      isCiSkip = false

    let number = buildNode["number"].getInt
    if number <= currentBuildNumber:  # -1 if unset
      break

    for changeNode in buildNode["changeSet"]["items"].elems:
      let comment = changeNode["comment"].getStr
      if comment.startsWith("[CI-SKIP]"):
        isCiSkip = true
        break
      let changeItem = ChangeItem(comment: comment, id: changeNode["commitId"].getStr)
      build.changeSet.add(changeItem)

    build.number = number
    build.date = times.fromUnixFloat(buildNode["timestamp"].getFloat / 1000).inZone(local())

    if not isCiSkip:
      result.add(build)

#
# formatting procs
#

proc format(date: DateTime): tuple[date: string; time: string] =
  result.date = [date.year.pad(4), date.month.ord.pad(2), date.monthday.pad(2)].join("-")
  result.time = [date.hour.pad(2), date.minute.pad(2)].join(":")

proc format*(build: Build, verbose = false): string =
  var lines = newSeq[string]()

  for i, changeItem in build.changeSet.pairs:  # for each changeItem (= commit)
    var commentLines = newSeq[string]()

    for line in changeItem.comment.splitLines:
      if line.strip.len > 0:
        commentLines.add(line)
        if not verbose:  # only include one line if not verbose
          break

    if i == 0 and verbose:
      let dateFmt = build.date.format
      commentLines[0].add(" - " & dateFmt.date & " " & dateFmt.time)  # show build date alongside topmost commit
    for j in 1..high(commentLines):
      commentLines[j] = repeat(' ', 15) & commentLines[j]

    let
      buildNumPart =
        if i == 0: &"#{pad(build.number, 3)} "
        else: ""
      commentJoined = commentLines.join("\n")
    lines.add(&"{buildNumPart}[{changeItem.id[0..6]}] {commentJoined}\n")
  
  if lines.len == 0:
    return ""

  for i in 1..high(lines):
    lines[i] = repeat(' ', 5) & lines[i]
  return lines.join("\n")

#
# export
#

proc getUpdates*(currentVersion: CurrentVersion): Updates =
  ## Given the current version, return a list of newer builds.
  
  result = Updates()
  
  let matchingVersion = getMatchingVersion(currentVersion.apiVer)
  if matchingVersion == "":
    return result
  result.version = matchingVersion

  result.builds = getNewBuilds(matchingVersion.semverGetMajor, currentVersion.buildNum)
