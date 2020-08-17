import httpclient

export httpclient

const
  NimblePkgVersion {.strdefine.} = "Unknown"
  headers = { "User-Agent": "updatepaper/" & NimblePkgVersion }

proc client*(): HttpClient =
  var c = newHttpClient()
  c.headers = newHttpHeaders(headers)
  return c
