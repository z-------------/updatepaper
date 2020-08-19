import os
import strutils
import math
import ./errorcodes

proc abs*(filename: string): string =
  joinPath(getCurrentDir(), filename)

proc print*(msg: string) {.inline.} =
  stdout.write(msg)

proc pad*(s: string; n: int; c = '0'): string =
  repeat(c, n - s.len) & s

proc pad*(s: int; n: int; c = '0'): string =
  pad($s, n, c)

proc progressBar*(p: float64; l = 75; c1 = '#'; c2 = '-'): string =
  let lm = (l - 2 - 5).float64  # 2 for the [], 5 for _000%
  "[" & repeat(c1, (p * lm).round.int) & repeat(c2, ((1 - p) * lm).round.int) & "] " & pad((p * 100).round.int, 3, ' ') & "%"

template logVerbose*(msg: string) =
  if args["--verbose"]:
    stdout.writeLine(msg)

proc die*(msg: string, code = QuitFailure) {.noreturn.} =
  stderr.writeLine(msg)
  quit(code)

proc moveFileOptional*(source, dest: string): bool {.discardable.} =
  try:
    moveFile(source, dest)
    return true
  except OSError:
    if osLastError().isEnoent:
      return false
    else:
      raise

proc removeFileOptional*(filename: string): bool {.discardable.} =
  try:
    removeFile(filename)
    return true
  except OSError:
    if osLastError().isEnoent:
      return false
    else:
      raise
