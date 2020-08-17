import json
import nre
import ./client

const Url = "https://papermc.io/js/downloads.js"

proc getDownloadsIndex*(): JsonNode =
  ## Fetch and parse the JSON table of downloadables.
  let data = client().getContent(Url)
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


when isMainModule:
  echo getDownloadsIndex()
