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
    version*: string
    filename*: string
    date*: DateTime
    changeSet*: seq[ChangeItem]
  Updates* = ref object
    version*: string
    builds*: seq[Build]

proc downloadUrl*(b: Build): string =
  &"https://papermc.io/api/v2/projects/paper/versions/{b.version}/builds/{b.number}/downloads/{b.filename}"

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
  &"https://papermc.io/api/v2/projects/paper/version_group/{majorVer}/builds"

iterator reverse[T](s: seq[T]): T =
  var i = s.high
  while i >= 0:
    yield s[i]
    i -= 1

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

  for buildNode in buildsJson.elems.reverse:
    var
      build = Build()
      isCiSkip = false

    let number = buildNode["build"].getInt
    if number <= currentBuildNumber:  # -1 if unset
      break

    for changeNode in buildNode["changes"].elems:
      let comment = changeNode["message"].getStr
      if comment.startsWith("[CI-SKIP]"):
        isCiSkip = true  # TODO: we should not filter out builds where only some commits are CI-SKIP
        break
      let changeItem = ChangeItem(comment: comment, id: changeNode["commit"].getStr)
      build.changeSet.add(changeItem)

    build.number = number
    build.date = times.parse(buildNode["time"].getStr, "YYYY-MM-dd'T'HH:mm:ss'.'fff'Z'", utc()).inZone(local())
    build.version = buildNode["version"].getStr
    build.filename = buildNode["downloads"]["application"]["name"].getStr

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
