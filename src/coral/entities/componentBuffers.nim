import std/typetraits

type
  SomeCompBuff* = object of RootObj
    name*: string
    dead: seq[int]

  CompBuff*[T] = object of SomeCompBuff
    components: seq[T]

proc initCompBuff*[T](): CompBuff[T] =
  result = CompBuff[T](components: @[], name: name(T))

proc del*(buff: var SomeCompBuff; idx: int) =
  buff.dead.add(idx)

proc get*[T](buff: CompBuff[T]; idx: int): lent T =
  buff.components[idx]

proc mget*[T](buff: var CompBuff[T]; idx: int): lent T =
  result = buff.components[idx]

proc mget*[T](buff: ptr CompBuff[T]; idx: int): lent T =
  result = buff[].components[idx]

proc add*[T](buff: ptr CompBuff[T]; comp: T): int =
  if buff.isNil:
    raise ValueError.newException("Buffer is nil!")
  if buff.dead.len > 0:
    result = buff[].dead.pop()
    buff[].components[result] = comp
  else:
    result = buff[].components.len()
    buff[].components.add(comp)
