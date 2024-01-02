import std/[macros, sequtils, strutils, tables, macrocache, enumerate, sugar]

import compBuffs, views, types

import ../core/[saving, typeids]

var entities = newSeq[EntId]()
var indexes = newSeq[Table[string, int]]()

const bufferCache = CacheSeq"bufferCache"
const bufferTypeCache = CacheSeq"bufferTypeCache"

proc nextEntId(): int =
  var nextId {.global.} = 0
  inc(nextId); nextId

proc spawn(): EntId =
  result = nextEntId().EntId
  entities.add(result)
  indexes.add(initTable[string, int]())

template compBuffName(n: NimNode): NimNode =
  ident(($n).toLower & "Buff")

macro registerComponents*(ts: untyped) =
  var buffers = nnkStmtList.newTree()
  for t in ts:
    let n = compBuffName(t)
    bufferCache.add(n)
    bufferTypeCache.add(t)
    buffers.add(quote do:
      var `n` {.used.} = initCompBuff[`t`]())
  buffers

macro add*[T](entId: EntId, comp: T) =
  var t = getTypeInst(comp)
  var n = compBuffName(t)
  var idx = strVal(t)
  quote do:
    indexes[int(`entId`) - 1][`idx`] = `n`.add(`comp`)

macro has*[T](entId: EntId, t: typedesc[T]): bool =
  var idx = strVal(t)
  quote do:
    indexes[int(`entId`) - 1].hasKey(`idx`)

macro mget*[T](entId: EntId, t: typedesc[T]): lent T =
  var n = compBuffName(t)
  var idx = strVal(t)
  quote do:
    `n`.mget(indexes[int(`entId`) - 1][`idx`])

macro componentBufferToJson(): auto =
  var xs = nnkStmtList.newTree()
  for c in bufferCache:
    xs.add(quote do: bs.add( % `c`))
  quote do:
    block:
      var bs {.inject.} = newJArray()
      `xs`
      bs

macro saveEntities*(): auto =
  var xs = nnkStmtList.newTree()

  for idx, buf in enumerate(bufferCache):
    xs.add(quote do:
      buffs["components"][`idx`]["data"] = newJArray()
      for comp in `buf`.data:
        buffs["components"][`idx`]["data"].add( % comp)
    )

  quote do:
    block:
      var buffs {.inject.} = %* {
        "entities": % entities,
        "indexes": % indexes,
        "components": componentBufferToJson()}
      `xs`
      buffs

macro loadEntities*(node: JsonNode) =
  var first = quote do:
    for ent in `node`["entities"]:
      entities.add(ent.getInt.EntId)
    for idx in `node`["indexes"]:
      var tbl = to(idx, Table[string, int])
      indexes.add(tbl)

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
        discard `buf`.add(`t`.load(c)))
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
macro view*(xs: untyped): auto =
  var ts = nnkCall.newTree(nnkDotExpr.newTree(ident("View"), ident("new")), )
  for x in xs:
    ts.add(quote do: getTypeId(`x`))
  ts

when isMainModule:
  type Pos = object
    x, y: float
  type Player = object
    test = 420

  dumpAstGen:
    View.new(Player, Pos)

  implSavable(Pos)
  implSavable(Player)

  registerComponents:
    Pos
    Player

  block:
    var ent = spawn()
    ent.add(Pos(x: 100.0, y: 200.0))
    ent.add(Player())

  block:
    var ent = spawn()
    ent.add(Pos(x: 100.0, y: 200.0))

  var es = saveEntities()
  resetEntities()
  loadEntities(es)