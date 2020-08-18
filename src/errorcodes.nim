import os

proc isEnoent*(e: OSErrorCode): bool =
  e.ord == 2

when isMainModule:
  try:
    moveFile("nonexist", "alsononexist")
  except OSError:
    echo osLastError().isEnoent
