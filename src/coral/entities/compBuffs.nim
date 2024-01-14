import std/[typetraits, sequtils]

import ../core/saving

type
  CompBuff*[T: SavableLoadable] = object
    name*: string
    dead*: seq[int]
    data*: seq[T]

proc `%`*[T: SavableLoadable](buf: CompBuff[T]): JsonNode =
  result = %* {
    "name": buf.name,
    "dead": % buf.dead}

proc initCompBuff*[T](): CompBuff[T] =
  result = CompBuff[T](
    data: @[], name: name(T),
    dead: @[]
  )

proc comps*[T](c: CompBuff[T]): lent seq[T] =
  result = c.data

template get*[T](buff: CompBuff[T]; idx: int): lent T =
  result = buff.data[idx]

proc mget*[T](buff: var CompBuff[T]; idx: int): ptr T =
  result = buff.data[idx].addr

proc add*[T](buff: var CompBuff[T]; comp: T): int =
  if buff.dead.len > 0:
    result = buff.dead.pop()
    if result >= buff.data.len:
      buff.data.setLen(result + 1)
    buff.data[result] = comp
  else:
    result = buff.data.len()
    buff.data.add(comp)

proc del*[T](buff: var CompBuff[T]; idx: int) =
  buff.dead.add(idx)
  buff.data[idx] = T.default()
