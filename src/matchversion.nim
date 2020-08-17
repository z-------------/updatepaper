import json
import ./util
import ./index

proc getMatchingVersion*(currentApiVer: string): string =
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
