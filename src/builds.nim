import json
import times
import strformat
import strutils
import ./client

type
  ChangeItem = ref object
    comment*: string
    id*: string
  Build* = ref object
    number*: int
    date*: DateTime
    changeSet*: seq[ChangeItem]

proc buildUrl(majorVer: string): string =
  &"https://papermc.io/ci/job/Paper-{majorVer}/api/json?tree=builds[number,timestamp,changeSet[items[comment,commitId,msg]]]"

proc getNewerBuilds*(majorVer: string; curBuildNum: int): seq[Build] =
  ## Given a major version string (e.g. "1.15") and the current build number,
  ## return a list of newer builds.
  let
    data = client().getContent(buildUrl(majorVer))
    buildsJson = parseJson(data)["builds"]

  for buildNode in buildsJson.elems:
    var
      build = Build()
      isCiSkip = false

    let number = buildNode["number"].getInt
    if number <= curBuildNum:  # curBuildNum is -1 if unset
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
