import nre
import json
import strutils
import ./util

const Filename = "version_history.json"

type CurrentVersion* = tuple[apiVer: string; buildNum: int]

let
  patApiVer = re"(?<=MC: )\d+\.\d+(\.\d+)?"
  patBuildNum = re"(?<=git-Paper-)\d+"

proc readVersionHistoryFile*(): CurrentVersion =
  ## Read and parse the version history file.
  let
    data = readFile(Filename.abs)
    versionInfo = parseJson(data)["currentVersion"].getStr
    matchApiVer = versionInfo.find(patApiVer)
    matchBuildNum = versionInfo.find(patBuildNum)
  
  if matchApiVer.isSome:
    result.apiVer = matchApiVer.get.match
  if matchBuildNum.isSome:
    result.buildNum = matchBuildNum.get.match.parseInt
