import std/[hashes, tables, typetraits]
import ../core/typeids

import compBuff, print

type
  EntId* = distinct int

  Ent = object
    id: EntId
    comps: TableRef[TypeId, int]

proc hash*(id: EntId): Hash {.borrow.}
proc `==`*(a, b: EntId): bool {.borrow.}

var
  dead: seq[EntId]
  entities: seq[Ent]
  compNames = newTable[TypeId, string]()
  compBuffs = newTable[TypeId, SomeCompBuff]()

proc init*(T: type Ent): T =
  result.comps = newTable[TypeId, int]()

proc isDead*(entId: EntId): bool =
  dead.contains(entId)

proc spawn*(): EntId =
  if dead.len > 0:
    result = dead.pop()
    entities[result.int] = default(Ent)
  else:
    result = entities.len().EntId
    entities.add(Ent(
      id: result,
      comps: newTable[TypeId, int]()))

proc add*[T](entId: EntId, comp: sink T) =
  let id = getTypeId(T)
  if not compBuffs.hasKey(id):
    compBuffs[id] = initCompBuff[T]()
    compNames[id] = name(T)
  var
    buff = cast[CompBuff[T]](compBuffs[id])
    idx = buff.add(comp)

  entities[entId.int].comps[id] = idx

proc get*[T: typedesc](entId: EntId, t: T): auto =
  var
    id = getTypeId(T)
    buff = cast[CompBuff[T]](compBuffs[id])
  buff.get(entities[entId.int].comps[id])

proc remove*[T: typedesc](id: EntId, t: T) =
  if not id.has(t):
    return

  var typeId = getTypeId(T)
  var e = entities[id.int].addr
  compBuffs[typeId].del(e.comps[typeId])
  e.comps.del(typeId)

proc del*(id: EntId) =
  var e = entities[id.int]
  dead.add(id)

  for compId in e.comps.keys:
    compBuffs[compId].del(e.comps[compId])

when isMainModule:
  type Pos = object
    x, y: float
  type Color = object
    r, g, b: int
  type Collidable = object

  var buf = initCompBuff[Pos]()
  var idx = buf.add(Pos(x: 1.0, y: 0.0))
  var p = buf.get(idx)

  p.x = 10.0

  var p2 = buf.get(idx)
  echo p2

  # var ent = spawn()
  # ent.add(Pos(x: 32.0))
  # ent.add(Color())
  # ent.add(Collidable())

  # var p = ent.get(Pos)

  # print(p)
