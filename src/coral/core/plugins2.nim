import tools, hashes, rdstdin, tables, strformat, sets, strutils, sugar,
    strutils, options, sequtils, algorithm

import std/[macros, macrocache]

type PluginId* = string

const functions = CacheTable"functions"
const functionCount = CacheTable"functionCounts"
const priority = CacheTable"priority"

var enabled: HashSet[PluginId]

macro plugin*(id, blk): auto =
  result = nnkStmtList.newTree()

  for child in blk.items:
    if child.kind != nnkProcDef:
      raiseAssert("Expected a proc definition got " & child.treeRepr)
    let name = child[0]
    let newIdStr = $child[0] & $id
    let newId = ident(newIdStr)
    var newProc = nnkProcDef.newTree(nnkPostfix.newTree(ident("*"), newId))
    var idx = 0

    for inner in child.items:
      if idx > 0:
        newProc.add(inner)
      idx += 1

    let reg = nnkCall.newTree(ident("register"), newLit($id), name, ident(newIdStr))
    result.add(quote do: `newProc`; `reg`)

  let name = $id
  result.add(quote do: enable(`name`))

proc isEnabled*(id: PluginId): bool = enabled.contains(id)
proc disable*(id: PluginId) = enabled.excl(id)
proc enable*(id: PluginId) = enabled.incl(id)

macro setPriority*(id: PluginId, p = 0) =
  if not priority.hasKey($id):
    priority[$id] = p

macro register*[S: enum](id: PluginId, step: S, fn: typed) =
  let idStep = fmt"{id}|{step}"

  var first = false

  if not functionCount.hasKey(idStep):
    functionCount[idStep] = newLit(0)
    first = true

  var count = functionCount[idStep].intVal
  functionCount[idStep].intVal = count + 1
  functions[idStep & "|" & $count] = fn

macro generatePluginStep*[S: enum](step: S, predicate: untyped = false): auto =
  result = nnkStmtList.newTree()

  var pluginIds = newSeq[(string, string)]()
  for key, _ in functions.pairs:
    pluginIds.add((key, key.split('|')[0]))
    result.add(newEmptyNode())

  pluginIds.sort do (x, y: (string, PluginId)) -> int:
    let pa =
      if priority.hasKey($x[1]): priority[$x[1]].intVal
      else: 0
    let pb =
      if priority.hasKey($y[1]): priority[$y[1]].intVal
      else: 0
    cmp(pa, pb)

  var idx = 0

  for (key, _) in pluginIds:
    let fun = functions[key]
    let xs = key.split '|'
    let pluginId = xs[0]
    let pluginStep = xs[1]

    if pluginStep != $step:
      continue

    let typeImpl = getTypeImpl(fun)

    var call = nnkCall.newTree(ident($fun))
    var isEmpty = true

    for arg in typeImpl[0].items:
      isEmpty = false
      if arg.kind == nnkIdentDefs:
        let id = arg[0]
        call.add(ident($id))

    if isEmpty:
      call.add(newEmptyNode())

    let checkedCall = block:
      if predicate != newLit(false):
        quote do:
          if isEnabled(`pluginId`) and `predicate`(`pluginId`):
            `call`
      else:
        quote do:
          if isEnabled(`pluginId`):
            `call`

    result[idx] = checkedCall
    idx += 1

when isMainModule:
  type Aa = object
  type Bb = object

  proc gameLoad(aa: Aa) =
    discard
  proc gameUpdate() =
    discard
  proc testLoad(bb: Bb) =
    discard
  proc testUpdate() =
    discard
  proc testUpdate2() =
    discard

  dumpAstGen:
    proc test*() =
      discard

  type
    Steps = enum
      load
      update
      draw
      unload

  register("game", load, gameLoad)
  register("game", update, gameUpdate)

  register("test", load, testLoad)
  register("test", update, testUpdate)
  register("test", update, testUpdate2)

  expandMacros:
    plugin(Health):
      proc load(aa: Aa) =
        echo("LOADED HEALTH")
      proc update(bb: Bb) =
        echo("UPDATE")

  var aa = Aa()
  var bb = Bb()

  proc shouldLoad(id: PluginId): bool =
    true

  # expandMacros:
  generatePluginStep[Steps](load, shouldLoad)
  generatePluginStep[Steps](update)
