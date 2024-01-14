import std/[macros, sequtils, strutils, tables, macrocache, enumerate, sugar, logging]

import compBuffs, views, types

import ../core/[saving, typeids]

export types, views

var entities = initHashSet[EntId]()
var dead = initHashSet[EntId]()
var indexes = newSeq[Table[TypeId, int]]()
var viewCache = initTable[ViewKey, View]()

const bufferCache = CacheSeq"bufferCache"
const bufferTypeCache = CacheSeq"bufferTypeCache"

proc getEntities*(): seq[EntId] =
  entities.toSeq

var nextId = 0

proc nextEntId(): int =
  inc(nextId)
  nextId

proc isDead*(id: EntId): bool =
  dead.contains(id)

proc spawn*(): EntId =
  if dead.len > 0:
    return dead.pop()

  result = nextEntId().EntId
  entities.incl(result)
  indexes.add(initTable[TypeId, int]())

template compBuffName(n: NimNode): NimNode =
  ident(($n).toLower & "Buff")

macro generateDeleters*(ts: untyped): untyped =
  var xs = nnkBracket.newTree()
  for t in ts:
    let n = compBuffName(t)
    xs.add(quote do:
      (typeId(`t`), proc(idx: int) = `n`.del(idx)))

  quote do:
    proc delete*(e: EntId, id: TypeId) =
      var idx = 0
      for (t, fn) in `xs`:
        if t == id:
          fn(indexes[e.int - 1][t])
          break
        inc(idx)

macro registerComponents*(ts: untyped) =
  var buffers = nnkStmtList.newTree()

  for t in ts:
    let n = compBuffName(t)
    bufferCache.add(n)
    bufferTypeCache.add(t)
    buffers.add(quote do:
      var `n`* {.used.} = initCompBuff[`t`]())

  quote do:
    `buffers`
    generateDeleters(`ts`)

template del*(entId: EntId) =
  dead.incl(entId)
  let ixs = indexes[entId.int - 1]
  for idx in ixs.keys:
    delete(entId, idx)

template deleteAllEntities*() =
  for ent in entities:
    ent.del()

macro addIt*(entId: EntId, comp: typed) =
  var t = getTypeInst(comp)
  var n = compBuffName(t)
  quote do:
    indexes[int(`entId`) - 1][typeId(`t`)] = `n`.add(`comp`)

proc add*[T](entId: EntId, comp: T): EntId {.discardable.} =
  entId.addIt(comp)
  entId

macro has*(entId: EntId, t: TypeId): bool =
  quote do:
    indexes[int(`entId`) - 1].hasKey(`t`)

macro has*(entId: EntId, t: untyped): bool =
  quote do:
    indexes[int(`entId`) - 1].hasKey(typeId(`t`))

macro mget*(entId: EntId, t: untyped): auto =
  var n = compBuffName(t)
  quote do:
    `n`.mget(indexes[int(`entId`) - 1][typeId(`t`)])

macro componentBufferToJson(): auto =
  var xs = nnkStmtList.newTree()
  for c in bufferCache:
    xs.add(quote do: bs.add( % `c`))
  quote do:
    block:
      var bs {.inject.} = newJArray()
      `xs`
      bs

proc `%`(tbls: seq[Table[TypeId, int]]): JsonNode =
  result = %* []
  for tbl in tbls:
    var t = %* {}
    for k, v in tbl.pairs:
      t[$k] = % v
    result.add(t)

macro saveEntities*(): auto =
  var xs = nnkStmtList.newTree()

  for idx, buf in enumerate(bufferCache):
    xs.add(quote do:
      buffs["components"][`idx`]["data"] = newJArray()
      for comp in `buf`.data:
        buffs["components"][`idx`]["data"].add( % comp))

  quote do:
    block:
      var deadJs = newJArray()
      for deadIdx in dead:
        deadJs.add( % deadIdx)

      var buffs {.inject.} = %* {
        "nextId": % nextId,
        "entities": % entities,
        "indexes": % indexes,
        "dead": deadJs,
        "components": componentBufferToJson()}
      `xs`
      buffs

proc initFromJson*[T: HashSet[EntId]](src: var T, node: JsonNode, path: var string) =
  for itm in node:
    src.incl(itm.getInt.EntId)

macro loadEntities*(node: JsonNode) =
  var first = quote do:
    nextId = `node`["nextId"].getInt
    entities = to(`node`["entities"], HashSet[EntId])

    indexes.setLen(0)
    for idx in `node`["indexes"]:
      var tbl = to(idx, Table[string, int])
      indexes.add(tbl.pairs.toSeq.mapIt((parseInt(it[0]).TypeId, it[1])).toTable)

    dead.clear()
    for d in `node`["dead"]:
      dead.incl(d.getInt.EntId)

  ## Note: this depends on components and buffer cache
  ## having the same order, we should sort both to ensure
  ## thats true

  var xs = nnkStmtList.newTree()
  var idx = 0
  for buf in bufferCache:
    var t = bufferTypeCache[idx]
    var s = newLit($t)
    xs.add(quote do:
      `buf` = CompBuff[`t`](name: `s`))
    xs.add(quote do:
      for idx in `node`["components"][`idx`]["dead"]:
        `buf`.dead.add(idx.getInt))
    xs.add(quote do:
      for c in `node`["components"][`idx`]["data"]:
        discard `buf`.add(`t`.load(`t`.migrate(c))))
    inc idx

  quote do:
    `first`
    `xs`

macro resetComponentBuffers*() =
  result = nnkStmtList.newTree()
  for buf in bufferCache:
    result.add(quote do: `buf`.data.setLen(0))

template resetEntities*() =
  resetComponentBuffers()
  indexes.setLen(0)
  entities.setLen(0)

## Views
macro createView*(xs: untyped): auto =
  var ts = nnkCall.newTree(nnkDotExpr.newTree(ident("View"), ident("new")))
  for x in xs:
    ts.add(quote do: getTypeId(`x`))
  ts

proc populate(view: View) =
  for e in entities:
    var matches = true

    for t in view.key:
      if not e.has(t):
        matches = false

    if matches:
      view.add(e)

proc view2*(ts: varargs[TypeId]): View =
  ## NOTE: we can't properly cache using this key
  result = View.new(ts)
  result.populate()

macro view*(ts: untyped): View =
  result = nnkCall.newTree(ident("view2"))
  for t in ts:
    result.add(quote do: typeId(`t`))

## Savable interface for the profile save
template generateEnts*() =
  type Ents* {.inject.} = object
  proc version*(T: type Ents): int = 1
  proc `%`*(s: Ents): JsonNode =
    info("Saved Entities")
    saveEntities()
  proc migrate*(T: type Ents, js: JsonNode): JsonNode = js
  proc load*(T: type Ents, n: JsonNode): T =
    loadEntities(n)
    info("Loaded Entities")
    Ents()

when isMainModule:
  import unittest

  type Pos = object
    x, y: float
  type Player = object
    test = 420

  implSavable(Pos)
  implLoadable(Pos)

  implSavable(Player)
  implLoadable(Player)

  registerComponents:
    Pos
    Player

  suite "Entities":
    test "We can add components":
      expandMacros:
        var ent = spawn()
          .add(Pos(x: 100.0, y: 200.0))
          .add(Player())

      var pos = ent.mget(Pos)
      echo pos[]

      echo ent.has(Pos)
      echo ent.has(Player)

      for id in view([Player]):
        echo "HERE:", id

      for id in view([Player]):
        echo "HERE:", id

      ent.del()

      # for id in view([Player]):
      #   echo "NOT HERE:", id
