import json
import times
import strformat
import strutils
import ./client
import ./index
import ./types

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
