import httpclient
import ./version

export httpclient

const headers = { "User-Agent": "updatepaper/" & PkgVersion }

proc client*(): HttpClient =
  var c = newHttpClient()
  c.headers = newHttpHeaders(headers)
  return c

proc asyncClient*(): AsyncHttpClient =
  var c = newAsyncHttpClient()
  c.headers = newHttpHeaders(headers)
  return c
