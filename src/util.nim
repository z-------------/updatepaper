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

proc getLogger*(verbose = false): (proc (msg: string)) =
  if verbose:
    (proc (msg: string) = stdout.writeLine(msg))
  else:
    (proc (msg: string) = discard)

proc die*(msg: string, code = QuitFailure) {.noreturn.} =
  stderr.writeLine(msg)
  quit(code)

proc moveFileOptional*(source, dest: string) =
  try:
    moveFile(source, dest)
  except OSError:
    if not osLastError().isEnoent:
      raise

proc removeFileOptional*(filename: string) =
  try:
    removeFile(filename)
  except OSError:
    if not osLastError().isEnoent:
      raise
