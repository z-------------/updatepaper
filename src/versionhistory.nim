import nre
import json
import strutils
import ./util
import ./types

const Filename = "version_history.json"

let
  patApiVer = re"(?<=MC: )\d+\.\d+(\.\d+)?"
  patBuildNum = re"(?<=git-Paper-)\d+"

proc readVersionHistoryFile*(): CurrentVersion =
  ## Read and parse the version history file.
  let
    data = readFile(Filename.rel)
    versionInfo = parseJson(data)["currentVersion"].getStr
    matchApiVer = versionInfo.find(patApiVer)
    matchBuildNum = versionInfo.find(patBuildNum)
  
  if matchApiVer.isSome:
    result.apiVer = matchApiVer.get.match
  if matchBuildNum.isSome:
    result.buildNum = matchBuildNum.get.match.parseInt
