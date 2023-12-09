import tools, hashes, rdstdin, tables, strformat, sets, strutils, sugar,
    strutils, options

import std/[macros, macrocache]

type
  AbstractPlugin = ref object of RootObj
  Plugin = ref object of AbstractPlugin

type PluginFunc = proc(): void

type PluginId = string

const functions = CacheTable"functions"
const functionCount = CacheTable"functionCounts"

var enabled: HashSet[PluginId]
var loaders: HashSet[PluginId]

# var functionValues: seq[]

# macro add*[S: enum](pluginId: PluginId, step: S, fun: untyped) =
#   functions.add((pluginId, step, fun))

proc shouldLoad(id: PluginId): bool = loaders.contains(id)
proc isEnabled(id: PluginId): bool = enabled.contains(id)
proc disable(id: PluginId) = enabled.excl(id)

macro register*[S: enum](id: PluginId, step: S, fn: typed) =
  let id = fmt"{id}|{step}"

  if not functionCount.hasKey(id):
    functionCount[id] = newLit(0)

  var count = functionCount[id].intVal
  functionCount[id].intVal = count + 1
  functions[id & "|" & $count] = fn

macro generatePluginSteps*[S: enum](step: S, predicate: untyped): auto =
  result = nnkStmtList.newTree()

  for key, fun in functions.pairs:
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

    var checkedCall = quote do:
      if isEnabled(`pluginId`) and `predicate`(`pluginId`):
        `call`
    result.add(checkedCall)

proc good(id: PluginId): bool {.inline.} = true
template generatePluginSteps*(step: untyped): auto =
  generatePluginSteps(step, good)

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

  var aa = Aa()
  var bb = Bb()

  expandMacros:
    generatePluginSteps[Steps](load, shouldLoad)
    generatePluginSteps[Steps](update)

  # var line: string
  # while true:
  #   let ok = readLineFromStdin("> ", line)
  #   if not ok:
  #     break
  #   echo(line)
