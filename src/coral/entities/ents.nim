import views, types, componentBuffers, fusion/matching, print
import ../core/[typeids, saving]
import std/[tables, hashes, macros, sequtils, typetraits, options]

export views, types, componentBuffers

type
  Ent = object
    id: EntId
    comps: TableRef[TypeId, int]

  Ents* = object
    dead: seq[EntId]
    entities: seq[Ent]
    views: seq[View]
    compBuffs: TableRef[TypeId, SomeCompBuff]

proc initEnt*(id: EntId): Ent =
  result = Ent(
    id: id,
    comps: newTable[TypeId, int]())

iterator entities*(ents: var Ents): EntId =
  for ent in ents.entities.items:
    if not ents.dead.contains(ent.id):
      yield ent.id

proc isDead*(ents: var Ents; entId: EntId): bool =
  ents.dead.contains(entId)

proc init*(T: type Ents): T =
  T(entities: @[],
    views: @[],
    compBuffs: newTable[TypeId, SomeCompBuff]())

proc spawn*(ents: var Ents): EntId =
  if ents.dead.len > 0:
    result = ents.dead.pop()
    ents.entities[result.int] = Ent(
      id: result,
      comps: newTable[TypeId, int]()
    )
  else:
    result = ents.entities.len().EntId
    ents.entities.add(initEnt(result))
  for view in ents.views:
    view.valid = false

proc add*[T](ents: var Ents; entId: EntId; comp: sink T) =
  let id = getTypeId(T)
  if not ents.compBuffs.hasKey(id):
    ents.compBuffs[id] = initCompBuff[T]()
  var
    buff = cast[ptr CompBuff[T]](ents.compBuffs[id].addr)
    idx = buff.add(comp)
  ents.entities[entId.int].comps[id] = idx

proc invalidateViewsWith(ents: var Ents; entId: EntId) =
  for view in ents.views.mitems:
    if view.contains(entId):
      view.valid = false

proc del*[T: typedesc](ents: var Ents; id: EntId; t: T) =
  if not ents.has(id, t):
    return
  var typeId = getTypeId(T)
  var e = ents.entities[id.int].addr
  ents.compBuffs[typeId].del(e.comps[typeId])
  e.comps.del(typeId)
  ents.invalidateViewsWith(id)

proc del*(ents: var Ents; id: EntId) =
  var e = ents.entities[id.int]
  ents.dead.add(id)
  for compId in e.comps.keys:
    ents.compBuffs[compId].del(e.comps[compId])
  ents.invalidateViewsWith(id)

proc has*(es: Ents; id: EntId; t: TypeId): bool =
  if not es.dead.contains(id):
    es.entities[id.int].comps.hasKey(t)
  else:
    false

proc has*(es: Ents; id: EntId; t: typedesc): bool =
  if not es.dead.contains(id):
    es.entities[id.int].comps.hasKey(getTypeId(t))
  else:
    false

proc andAll*(vs: varargs[bool]): bool =
  result = true
  for v in vs:
    result = result and v

template hasImpl() =
  var ts = nnkCall.newTree(ident("andAll"))
  for t in types:
    ts.add(nnkCall.newTree(
      nnkDotExpr.newTree(es, ident("has")), id, ident($t)))
  result = nnkStmtList.newTree(ts)

macro has*(es, id: untyped; types: openArray[typedesc]): untyped = hasImpl()

proc has*(es: Ents; id: EntId; types: openArray[TypeId]): bool =
  result = true
  for t in types:
    if es.dead.contains(id) or not es.has(id, t):
      return false

proc get*[T: typedesc](ents: Ents; entId: EntId; t: T): auto =
  var
    name = getTypeId(T)
    buff = cast[CompBuff[T]](ents.compBuffs[name])
  result = buff.get(ents.entities[entId.int].comps[name])

macro get*(es, id: untyped; types: openArray[typedesc]): untyped =
  var vs = nnkPar.newTree()

  for t in types:
    vs.add(nnkCall.newTree(
        nnkDotExpr.newTree(es, newIdentNode("get")),
        id, ident($t)))

  result = nnkStmtList.newTree(vs)

proc mget*[T: typedesc](ents: var Ents; entId: EntId; t: T): ptr t =
  var
    id = getTypeId(t)
    buffPtr: ptr SomeCompBuff = ents.compBuffs[id].addr
    buff = cast[ptr CompBuff[T]](buffPtr)
  result = buff.mget(ents.entities[entId.int].comps[id]).addr

macro mget*(es, id: untyped; types: openArray[typedesc]): untyped =
  var vs = nnkPar.newTree()
  for t in types:
    vs.add(nnkCall.newTree(
        nnkDotExpr.newTree(es, newIdentNode("mget")),
        id, ident($t)))
  result = nnkStmtList.newTree(vs)

proc populate(ents: var Ents; view: View) =
  view.clear()
  for ent in ents.entities:
    if view.contains(ent.id):
      continue
    var ks = view.keys.toSeq()
    if ents.has(ent.id, ks):
      view.add(ent.id)
  view.valid = true

proc view*(ents: var Ents; ts: openArray[TypeId]): auto =
  for view in ents.views.mitems:
    if view.keyMatch(ts):
      if not view.valid:
        ents.populate(view)
      return view
  result = View.new(ts)
  ents.populate(result)
  ents.views.add(result)

proc view*[T: typedesc](ents: var Ents; t: T): auto =
  for view in ents.views.mitems:
    if view.keyMatch([t.getTypeId]):
      if not view.valid:
        ents.populate(view)
      return view
  result = View.new(t.getTypeId)
  ents.populate(result)
  ents.views.add(result)

macro view2(entsIdent: untyped; ts: untyped): untyped =
  result = nnkStmtList.newTree()
  var call = nnkCall.newTree(nnkDotExpr.newTree(entsIdent, ident("view")))
  var brac = nnkBracket.newTree()
  for x in ts:
    brac.add(nnkDotExpr.newTree(ident($x), ident("getTypeId")))
  call.add(brac)
  result.add(call)

template view*(ents: var Ents; xs: openArray[typedesc]): auto =
  view2(ents, xs)

proc update*(ents: Ents) =
  discard

## Saving and loading entities
var compSaveHook = none(proc(buff: SomeCompBuff): seq[JsonNode])

proc componentSaveHook*(fn: proc(buff: SomeCompBuff): seq[JsonNode]) =
  compSaveHook = some(fn)

proc `%`(comps: TableRef[TypeId, int]): JsonNode =
  result = %* {}
  for k, v in comps.pairs:
    result[$k] = % v

proc version*(T: type Ent): int = 1
proc save*(e: Ent): JsonNode =
  %* {"id": % e.id, "comps": % e.comps}
proc `%`(e: Ent): JsonNode = e.save()
proc migrate*(T: type Ent; js: JsonNode): JsonNode = js
proc load*(T: type Ent; n: JsonNode): T = to(T.migrate(n), T)

proc `%`(compBuffs: TableRef[TypeId, SomeCompBuff]): JsonNode =
  result = %* {}
  if Some(@hook) ?= compSaveHook:
    for k, v in compBuffs.pairs:
      ## HACK! I don't know how there are empty component buffs,
      ## I've looked at all of the places we're adding them, and im
      ## not finding it, wonder if its a copy error

      result[$k] = v.save()
      result[$k]["components"] = % hook(v)

proc version*(T: type Ents): int = 1
proc save*(s: Ents): JsonNode =
  %* {
    "dead": % s.dead,
    "entities": % s.entities,
    "views": % s.views,
    "compBuffs": % s.compBuffs}
proc migrate*(T: type Ents; js: JsonNode): JsonNode = js
proc load*(T: type Ents; n: JsonNode): T = to(T.migrate(n), T)

static:
  assert Ents is Savable
  assert Ents is Loadable
  assert Ent is Savable
  assert Ent is Loadable
