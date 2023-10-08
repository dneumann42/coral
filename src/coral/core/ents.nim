import tables, typetraits, typeinfo, std/[enumerate], macros, json, sugar,
    vmath, strutils, unittest
import typeids, jsony, sets
import strformat

type
  EntId* = int

  AbstractCompBuff* = ref object of RootObj
    name*: string

  CompBuff*[T] = ref object of AbstractCompBuff
    components: seq[T]
    dead: seq[int]

  View* = object
    # TODO: Test if using a seq is faster, could be for keys since the list should
    # be relatively small
    keys: HashSet[string]
    entities: HashSet[string]

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

proc init(T: type View, keys = initHashSet[string]()): T =
  T(keys: keys, entities: initHashSet[string]())
proc init(T: type View, keys: varargs[string]): T = T.init(
    keys = keys.toHashSet())
proc init(T: type View, keys: UncheckedArray[string]): T = T.init(
    keys = keys.toHashSet())

func hasKey*(view: View, key: string): bool =
  result = view.keys.contains(key)

iterator keys*(view: View): string =
  for k in view.keys:
    yield k

proc keyMatch(view: View, keys: openArray[string]): bool =
  if view.keys.len != keys.len:
    return false
  result = true
  for k in keys:
    if not view.hasKey(k):
      return false

iterator entities*(view: View): string =
  for ent in view.entities:
    # TODO: validate each entity is valid before yielding
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
    comps: initTable[TypeId, int]()
  )

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

proc has*(es: Ents, id: EntId, t: typedesc): bool =
  es.entities[id].comps.hasKey(getTypeId(t))

proc andAll*(vs: varargs[bool]): bool =
  result = true
  for v in vs:
    result = result and v

macro has*(es, id: untyped, types: openArray[typedesc]): untyped =
  var ts = nnkCall.newTree(ident("andAll"))
  for t in types:
    ts.add(nnkCall.newTree(
      nnkDotExpr.newTree(es, ident("has")), id, ident($t)))
  result = nnkStmtList.newTree(ts)

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

proc view*[T: typedesc](ents: Ents, entId: EntId, t: T): auto =
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
      js["compBuffs"][key]
    )

when isMainModule:
  {.experimental: "caseStmtMacros".}
  type A = object
    value = 3.14
  type B = object
  type C = object

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
      a.value = 42.0
      check(es.get(id, A).value == 42.0)

      var a2 = es.get(id, A)
      a2.value = 32.0
      check(es.get(id, A).value != 32.0)

  suite "using views to iterate entities and components":
    test "we can match keys":
      let view = View.init(name(A), name(B), name(C))
      check(view.keyMatch(@["A", "B", "C"]))
      check(not view.keyMatch(@["A", "B"]))
      check(not view.keyMatch(@["A", "B", "D"]))

    test "we can iterate entities using views":
      discard
