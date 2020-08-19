import times

type CurrentVersion* = tuple[apiVer: string; buildNum: int]

type
  ChangeItem* = ref object
    comment*: string
    id*: string
  Build* = ref object
    number*: int
    date*: DateTime
    changeSet*: seq[ChangeItem]
  Updates* = ref object
    version*: string
    builds*: seq[Build]
