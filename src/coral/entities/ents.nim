import views, types, componentBuffers

import ../core/typeids

import std/[tables, hashes, macros, sequtils, typetraits]

export views, types

type
  Ent = object
    id: EntId
    comps: TableRef[TypeId, int]

  Ents* = object
    dead: seq[EntId]
    entities: seq[Ent]
    views: seq[View]
    compNames: Table[TypeId, string]
    compBuffs: Table[TypeId, SomeCompBuff]

proc `=sink`*(x: var Ents; y: Ents) {.error.}
proc `=copy`*(x: var Ents; y: Ents) {.error.}
proc `=wasMoved`*(x: var Ents) {.error.}

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
    compBuffs: initTable[TypeId, SomeCompBuff](),
    compNames: initTable[TypeId, string]())

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
    ents.compNames[id] = name(T)
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