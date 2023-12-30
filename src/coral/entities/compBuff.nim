import sequtils, print

type
  CompIdx* = int
  SomeCompBuff* = ref object of RootObj
    dead*: seq[CompIdx]

  CompBuff*[T] = ref object of SomeCompBuff
    components*: seq[T]

proc initCompBuff*[T](): CompBuff[T] =
  result = CompBuff[T]()
  result.components = @[]

proc del*(buff: var SomeCompBuff; idx: int) =
  buff.dead.add(idx)

proc get*[T](buff: CompBuff[T]; idx: int): var T =
  buff.components[idx]

proc mget*[T](buff: CompBuff[T]; idx: int): var T =
  buff.components[idx]

proc add*[T](buff: var CompBuff[T]; comp: sink T): int =
  if buff.dead.len > 0:
    let idx = buff.dead.pop()
    buff.components[idx] = comp
    return idx
  result = len(buff.components)
  buff.components.add(comp)
