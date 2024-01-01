import tables, typetraits, typeinfo, std/[enumerate], macros, json, sugar,
    vmath, strutils, unittest, options, sequtils, print, hashes
import ../core/typeids, jsony, sets, strformat

type
  EntId* = distinct int

  SomeCompBuff* = object of RootObj
    name*: string
    dead: seq[int]

  CompBuff*[T] = object of SomeCompBuff
    components: seq[T]

  View* = ref object
    valid: bool
    keys: seq[TypeId]
    entities: seq[EntId]

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

proc `==`*(a, b: EntId): bool {.borrow.}
proc hash*(a: EntId): Hash {.borrow.}

proc initEnt*(id: EntId): Ent =
  result = Ent(
    id: id,
    comps: newTable[TypeId, int]())

proc new(T: type View; keys = newSeq[TypeId]()): T = T(keys: keys, entities: @[])
proc new(T: type View; keys: varargs[TypeId]): T = T.new(@keys)
proc new(T: type View; keys: UncheckedArray[TypeId]): T = T.new(@keys)

func hasKey*(view: View; key: TypeId): bool =
  result = view.keys.contains(key)

iterator keys*(view: View): TypeId =
  for k in view.keys:
    yield k

proc keyMatch(view: View; keys: openArray[TypeId]): bool =
  if view.keys.len != keys.len:
    return false
  result = true
  for k in keys:
    if not view.hasKey(k):
      return false

iterator entities*(view: View): EntId =
  for ent in view.entities:
    yield ent

iterator items*(view: View): EntId =
  for ent in view.entities:
    yield ent

iterator entities*(ents: var Ents): EntId =
  for ent in ents.entities.items:
    if not ents.dead.contains(ent.id):
      yield ent.id

proc initCompBuff*[T](): CompBuff[T] =
  result = CompBuff[T](
    components: @[],
    name: name(T),
  )

proc isDead*(ents: var Ents; entId: EntId): bool =
  ents.dead.contains(entId)

proc add*[T](buff: ptr CompBuff[T]; comp: T): int =
  if buff.isNil:
    raise ValueError.newException("Buffer is nil!")
  if buff.dead.len > 0:
    result = buff[].dead.pop()
    buff[].components[result] = comp
  else:
    result = buff[].components.len()
    buff[].components.add(comp)

    # if buff[].components.isNil:
    #   raise CatchableError.newException("Components seq is nil")

proc del*(buff: var SomeCompBuff; idx: int) =
  buff.dead.add(idx)

proc get*[T](buff: CompBuff[T]; idx: int): lent T =
  buff.components[idx]

proc mget*[T](buff: var CompBuff[T]; idx: int): lent T =
  result = buff.components[idx]
proc mget*[T](buff: ptr CompBuff[T]; idx: int): lent T =
  echo(buff[])
  result = buff[].components[idx]

proc init*(T: type Ents): T =
  T(entities: @[],
    views: @[],
    compBuffs: initTable[TypeId, SomeCompBuff](),
    compNames: initTable[TypeId, string]())

proc spawn*(ents: var Ents): EntId =
  # if ents.dead.len > 0:
  #   result = ents.dead.pop()

  #   ## TODO: Reuse memory
  #   ents.entities[result.int] = Ent(
  #     id: result,
  #     comps: newTable[TypeId, int]()
  #   )
  # else:
  result = ents.entities.len().EntId
  ents.entities.add(initEnt(result))

  # # TODO: only invalidate the views that match the entities components
  # for view in ents.views:
  #   view.valid = false
  discard

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
    if view.entities.contains(entId):
      view.valid = false

proc remove*[T: typedesc](ents: var Ents; id: EntId; t: T) =
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

proc mget*[T: typedesc](ents: var Ents; entId: EntId; t: T): auto =
  var
    id = getTypeId(t)
    buffPtr: ptr SomeCompBuff = ents.compBuffs[id].addr
    buff = cast[ptr CompBuff[T]](buffPtr)
  result = buff.mget(ents.entities[entId.int].comps[id])

macro mget*(es, id: untyped; types: openArray[typedesc]): untyped =
  var vs = nnkPar.newTree()
  for t in types:
    vs.add(nnkCall.newTree(
        nnkDotExpr.newTree(es, newIdentNode("mget")),
        id, ident($t)))
  result = nnkStmtList.newTree(vs)

proc populate(ents: var Ents; view: View) =
  view.entities.setLen(0)
  for ent in ents.entities:
    if view.entities.contains(ent.id):
      continue
    var ks = view.keys
    if ents.has(ent.id, ks):
      view.entities.add(ent.id)
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

proc dumpHook(s: var string; k: Table[TypeId, SomeCompBuff]) =
  s.add("{}")

proc dumpHook(s: var string; ks: Table[TypeId, string]) =
  s.add("{")
  for (i, k) in enumerate(ks.keys):
    s.add(&"\"{k}\": \"{ks[k]}\"")
    if i + 1 < ks.len:
      s.add(", ")
  s.add("}")

proc dumpHook(s: var string; ks: Table[TypeId, int]) =
  s.add("{")
  for (i, k) in enumerate(ks.keys):
    s.add(&"\"{k}\": {ks[k]}")
    if i + 1 < ks.len:
      s.add(", ")
  s.add("}")

proc save*(ents: Ents; comp: (abs: SomeCompBuff) ->
    string): string =
  var js = jsony.toJson(ents).parseJson()
  var buffs = js["compBuffs"]
  for k in ents.compBuffs.keys:
    let buffSave = comp(ents.compBuffs[k])
    buffs.add($k, buffSave.parseJson())
  js.pretty

proc load*(code: string; comp: (node: JsonNode) -> SomeCompBuff): Ents =
  let js = code.parseJson()
  result = Ents.init()

  for ent in js["entities"]:
    var ts = newTable[TypeId, int]()
    for key in ent["comps"].keys():
      ts[parseInt(key)] = ent["comps"][key].getInt
    result.entities.add(Ent(id: ent["id"].getInt.EntId, comps: ts))

  for key in js["compNames"].keys():
    result.compNames[parseInt(key)] = js["compNames"][key].getStr

  for key in js["compBuffs"].keys():
    result.compBuffs[parseInt(key)] = comp(
      js["compBuffs"][key])

when isMainModule:
  {.experimental: "caseStmtMacros".}
  type A = object
    value = 3.14
  type B = object
  type C = object
  type D = object

  suite "Adding / Getting and Removing components":
    var
      es = Ents.init()
      id = es.spawn()

    test "adding and getting components":
      let (a, b, c) = es.get(id, [A, B, C])
      check(a is A)
      check(b is B)
      check(c is C)

    test "getting components and changing values":
      var a = es.mget(id, A)
      check(es.has(id, [A, B]))
      a.value = 42.0
      check(es.get(id, A).value == 42.0)

      var a2 = es.get(id, A)
      a2.value = 32.0
      check(es.get(id, A).value != 32.0)

  suite "Checking for components":
    var
      es = Ents.init()
      id = es.spawn()

    test "checking components":
      check(getTypeId(A) != getTypeId(B))
      check(es.has(id, [A, B]))
      check(es.has(id, A))
      check(not es.has(id, C))
      check(es.has(id, getTypeId(A)))

  suite "using views to iterate entities and components":
    var
      es = Ents.init()

      ae = es.spawn()
      be = es.spawn()
      ce = es.spawn()

    test "can match keys":
      let view = View.new(getTypeId(A), getTypeId(B), getTypeId(C))
      check(view.keyMatch([A.getTypeId]) == false)
      check(view.keyMatch([A.getTypeId, B.getTypeId]) == false)
      check(view.keyMatch([A.getTypeId, B.getTypeId, C.getTypeId]) == true)
      check(view.keyMatch([A.getTypeId, B.getTypeId, C.getTypeId,
          D.getTypeId]) == false)

    test "can iterate entities using views":
      let aes = es.view(A).entities.toSeq()
      let bes = es.view(B).entities.toSeq()
      let ces = es.view(C).entities.toSeq()

      let aandbs = es.view([A, B]).entities.toSeq()

      check(es.has(ae, [A, B, C]) == true)
      check(es.has(be, [A, B]) == true)
      check(es.has(be, C) == false)
      check(es.has(ce, [A]) == true)
      check(es.has(be, [B, C]) == false)

      check(aes.len() == 3)
      check(bes.len() == 2)
      check(ces.len() == 1)
      check(aandbs.len() == 2)

    test "can remove components":
      check(es.has(ae, B))
      check(es.has(be, B))

      es.remove(be, B)

      check(es.has(ae, B))
      check(es.has(be, B) == false)