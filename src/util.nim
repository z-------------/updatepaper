import os
import strutils
import strformat
import times
import math
from ./builds import Build
import ./errorcodes

proc rel*(filename: string): string =
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

proc semverGetMajor*(v: string): string =
  v.split(".")[0..1].join(".")

proc semverSplit*(v: string): seq[int] =
  for part in v.split("."):
    result.add(parseInt(part))

proc semverEq*(verA, verB: string; n = 3): bool =
  if verA.len == 0:
    return true
  let
    splitA = verA.semverSplit
    splitB = verB.semverSplit
  for i in 0..<n:
    if splitA[i] != splitB[i]:
      return false
  return true

proc buildNumberGt*(bnA, bnB: int): bool =
  bnA == -1 or bnB > bnA

proc formatDate(date: DateTime): tuple[date: string; time: string] =
  result.date = [date.year.pad(4), date.month.ord.pad(2), date.monthday.pad(2)].join("-")
  result.time = [date.hour.pad(2), date.minute.pad(2)].join(":")

proc formatBuildInfo*(build: Build, verbose = false): string =
  var lines = newSeq[string]()

  for i, changeItem in build.changeSet.pairs:  # for each changeItem (= commit)
    var commentLines = newSeq[string]()

    for line in changeItem.comment.splitLines:
      if line.strip.len > 0:
        commentLines.add(line)
        if not verbose:  # only include one line if not verbose
          break

    if i == 0 and verbose:
      let dateFmt = build.date.formatDate
      commentLines[0].add(" - " & dateFmt.date & " " & dateFmt.time)  # show build date alongside topmost commit
    for j in 1..high(commentLines):
      commentLines[j] = repeat(' ', 15) & commentLines[j]

    let
      buildNumPart =
        if i == 0: &"#{pad(build.number, 3)} "
        else: ""
      commentJoined = commentLines.join("\n")
    lines.add(&"{buildNumPart}[{changeItem.id[0..6]}] {commentJoined}\n")
  
  if lines.len == 0:
    return ""

  for i in 1..high(lines):
    lines[i] = repeat(' ', 5) & lines[i]
  return lines.join("\n")

proc underline*(text: string): string =
  text & "\n" & repeat('=', text.len)

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
    if osLastError() != OSErrorCode(ENOENT):
      raise

proc removeFileOptional*(filename: string) =
  try:
    removeFile(filename)
  except OSError:
    if osLastError() != OSErrorCode(ENOENT):
      raise
