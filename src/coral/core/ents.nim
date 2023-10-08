import tables, typetraits, typeinfo, std/[enumerate], macros, json, sugar,
    vmath, strutils, unittest, options, sequtils
import typeids, jsony, sets, macros
import strformat

type
  EntId* = int

  AbstractCompBuff* = ref object of RootObj
    name*: string

  CompBuff*[T] = ref object of AbstractCompBuff
    components: seq[T]
    dead: seq[int]

  View* = ref object
    valid: bool
    keys: seq[TypeId]
    entities: seq[EntId]

  Ent = object
    id: EntId
    comps: Table[TypeId, int]

  Ents* = object
    entities: seq[Ent]
    views: seq[View]
    compNames: Table[TypeId, string]
    compBuffs: Table[TypeId, AbstractCompBuff]

proc ent*(): Ent =
  result.comps = initTable[TypeId, int]()

proc new(T: type View, keys = newSeq[TypeId]()): T = T(keys: keys, entities: @[])
proc new(T: type View, keys: varargs[TypeId]): T = T.new(@keys)
proc new(T: type View, keys: UncheckedArray[TypeId]): T = T.new(@keys)

func hasKey*(view: View, key: TypeId): bool =
  result = view.keys.contains(key)

iterator keys*(view: View): TypeId =
  for k in view.keys:
    yield k

proc keyMatch(view: View, keys: openArray[TypeId]): bool =
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
    yield ent.id

proc initCompBuff*[T](): CompBuff[T] =
  result = new(CompBuff[T])
  result.components = @[]
  result.name = name(T)

proc add*[T](buff: var CompBuff[T], comp: T): int =
  if buff.dead.len > 0:
    let idx = buff.dead.pop()
    buff.components[idx] = comp
    result = idx
  else:
    result = len(buff.components)
    buff.components.add(comp)

proc del*[T](buff: var CompBuff[T], idx: int) =
  buff.dead.add(idx)

proc get*[T](buff: CompBuff[T], idx: int): T =
  buff.components[idx]

proc mget*[T](buff: var CompBuff[T], idx: int): ptr T =
  result = buff.components[idx].addr

proc init*(T: type Ents): T =
  T(entities: @[],
    views: @[],
    compBuffs: initTable[TypeId, AbstractCompBuff](),
    compNames: initTable[TypeId, string]())

proc spawn*(ents: var Ents): EntId =
  result = ents.entities.len()
  ents.entities.add Ent(
    id: result,
    comps: initTable[TypeId, int]())

  # TODO: only invalidate the views that match the entities components
  for view in ents.views:
    view.valid = false

proc add*[T](ents: var Ents, entId: EntId, comp: T): var Ents {.discardable.} =
  result = ents
  let id = getTypeId(T)

  if not ents.compBuffs.hasKey(id):
    ents.compBuffs[id] = initCompBuff[T]()
    ents.compNames[id] = name(T)

  var
    buff = cast[CompBuff[T]](ents.compBuffs[id])
    idx = buff.add(comp)

  ents.entities[entId].comps[name] = idx

type
  EntAdd = ref object
    id: EntId
    ents: var Ents

proc a*[T](ent: EntAdd, c: T): EntAdd {.discardable.} =
  let id = getTypeId(T)
  if not ent.ents.compBuffs.hasKey(id):
    ent.ents.compNames[id] = name(T)
    ent.ents.compBuffs[id] = initCompBuff[T]()
  var
    buff = cast[CompBuff[T]](ent.ents.compBuffs[id])
    idx = buff.add(c)
  ent.ents.entities[ent.id].comps[id] = idx
  result = ent

proc kill*(ents: var Ents, entId: EntId) =
  # TODO: delete entity from views
  discard

converter toEnts*(entAdd: EntAdd): var Ents =
  result = entAdd.ents

proc add*(ents: var Ents, e: EntId): EntAdd {.discardable.} =
  result = EntAdd(ents: ents, id: e)

proc has*(es: Ents, id: EntId, t: TypeId): bool =
  es.entities[id].comps.hasKey(t)
proc has*(es: Ents, id: EntId, t: typedesc): bool =
  es.entities[id].comps.hasKey(getTypeId(t))

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

macro has*(es, id: untyped, types: openArray[typedesc]): untyped = hasImpl()

proc has*(es: Ents, id: EntId, types: openArray[TypeId]): bool =
  result = true
  for t in types:
    if not es.has(id, t):
      return false

proc get*[T: typedesc](ents: Ents, entId: EntId, t: T): auto =
  var
    name = getTypeId(T)
    buff = cast[CompBuff[T]](ents.compBuffs[name])
  result = buff.get(ents.entities[entId].comps[name])

macro get*(es, id: untyped, types: openArray[typedesc]): untyped =
  var vs = nnkPar.newTree()

  for t in types:
    vs.add(nnkCall.newTree(
        nnkDotExpr.newTree(es, newIdentNode("get")),
        id, ident($t)))

  result = nnkStmtList.newTree(vs)

proc mget*[T: typedesc](ents: var Ents, entId: EntId, t: T): auto =
  var
    name = getTypeId(t)
    buff = cast[CompBuff[T]](ents.compBuffs[name])
  result = buff.mget(ents.entities[entId].comps[name])

macro mget*(es, id: untyped, types: openArray[typedesc]): untyped =
  var vs = nnkPar.newTree()
  for t in types:
    vs.add(nnkCall.newTree(
        nnkDotExpr.newTree(es, newIdentNode("mget")),
        id, ident($t)))
  result = nnkStmtList.newTree(vs)

proc populate(ents: var Ents, view: View) =
  for ent in ents.entities:
    if view.entities.contains(ent.id):
      continue
    var ks = view.keys
    if ents.has(ent.id, ks):
      view.entities.add(ent.id)

  view.valid = true

proc view*(ents: var Ents, ts: openArray[TypeId]): auto =
  for view in ents.views.mitems:
    if view.keyMatch(ts):
      if not view.valid:
        ents.populate(view)
      return view
  result = View.new(ts)
  ents.populate(result)
  ents.views.add(result)

proc view*[T: typedesc](ents: var Ents, t: T): auto =
  for view in ents.views.mitems:
    if view.keyMatch([t.getTypeId]):
      if not view.valid:
        ents.populate(view)
      return view
  result = View.new(t.getTypeId)
  ents.populate(result)
  ents.views.add(result)

macro view2(entsIdent: untyped, ts: untyped): untyped =
  result = nnkStmtList.newTree()
  var call = nnkCall.newTree(nnkDotExpr.newTree(entsIdent, ident("view")))
  var brac = nnkBracket.newTree()
  for x in ts:
    brac.add(nnkDotExpr.newTree(ident($x), ident("getTypeId")))
  call.add(brac)
  result.add(call)

template view(ents: var Ents, xs: openArray[typedesc]): auto =
  view2(ents, xs)

proc update*(ents: Ents) =
  discard

proc dumpHook(s: var string, k: Table[TypeId, AbstractCompBuff]) =
  s.add("{}")

proc dumpHook(s: var string, ks: Table[TypeId, string]) =
  s.add("{")
  for (i, k) in enumerate(ks.keys):
    s.add(&"\"{k}\": \"{ks[k]}\"")
    if i + 1 < ks.len:
      s.add(", ")
  s.add("}")

proc dumpHook(s: var string, ks: Table[TypeId, int]) =
  s.add("{")
  for (i, k) in enumerate(ks.keys):
    s.add(&"\"{k}\": {ks[k]}")
    if i + 1 < ks.len:
      s.add(", ")
  s.add("}")

proc save*(ents: Ents, comp: (abs: AbstractCompBuff) ->
    string): string =
  var js = jsony.toJson(ents).parseJson()
  var buffs = js["compBuffs"]
  for k in ents.compBuffs.keys:
    let buffSave = comp(ents.compBuffs[k])
    buffs.add($k, buffSave.parseJson())
  js.pretty

proc load*(code: string, comp: (node: JsonNode) -> AbstractCompBuff): Ents =
  let js = code.parseJson()
  result = Ents.init()

  for ent in js["entities"]:
    var ts = initTable[TypeId, int]()
    for key in ent["comps"].keys():
      ts[parseInt(key)] = ent["comps"][key].getInt
    result.entities.add(Ent(id: ent["id"].getInt, comps: ts))

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
    es.add(id).a(A()).a(B()).a(C())

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
    es.add(id).a(A()).a(B())

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

    es.add(ae).a(A(value: 1.0)).a(B()).a(C())
    es.add(be).a(A(value: 2.0)).a(B())
    es.add(ce).a(A(value: 3.0))

    test "we can match keys":
      let view = View.new(getTypeId(A), getTypeId(B), getTypeId(C))
      check(view.keyMatch([A.getTypeId]) == false)
      check(view.keyMatch([A.getTypeId, B.getTypeId]) == false)
      check(view.keyMatch([A.getTypeId, B.getTypeId, C.getTypeId]) == true)
      check(view.keyMatch([A.getTypeId, B.getTypeId, C.getTypeId,
          D.getTypeId]) == false)

    test "we can iterate entities using views":
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
