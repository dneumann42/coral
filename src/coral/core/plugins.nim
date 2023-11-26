import std/logging, strutils, sequtils, tables, typetraits
import sugar, events, tables, patty, options, commands, states, ents
import ../artist/artist

import std/macros
import std/macrocache

proc perm[T](a: openarray[T], n: int, use: var seq[bool]): seq[seq[T]] =
  result = newSeq[seq[T]]()
  if n <= 0: return
  for i in 0 .. a.high:
    if not use[i]:
      if n == 1:
        result.add(@[a[i]])
      else:
        use[i] = true
        for j in perm(a, n - 1, use):
          result.add(a[i] & j)
        use[i] = false

proc permutations[T](a: openarray[T], n: int): seq[seq[T]] =
  var use = newSeq[bool](a.len)
  perm(a, n, use)

const typeTable = CacheTable"typeTable"

static:
  typeTable["a"] = ident("Artist")
  typeTable["e"] = ident("Events")
  typeTable["s"] = ident("GameState")
  typeTable["c"] = ident("Commands")
  typeTable["n"] = ident("Ents")

const FUNCTION_NAMES = block:
  let keys = collect(for k, _ in typeTable: k)
  permutations(keys, 1).mapIt(it.join())
    .concat(permutations(keys, 2).mapIt(it.join()))
    .concat(permutations(keys, 3).mapIt(it.join()))
    .concat(permutations(keys, 4).mapIt(it.join()))
    .concat(permutations(keys, 5).mapIt(it.join()))
    .mapIt("Fn" & it.toUpperAscii)
    .concat(@["Fn"])

macro generateFunctionTypes() =
  var sec = nnkTypeSection.newTree()

  for fn in FUNCTION_NAMES:
    var def = nnkTypeDef.newTree(ident(fn), newEmptyNode())
    var prc = nnkProcTy.newTree()
    var params = nnkFormalParams.newTree(ident("void"))

    for i in 2..<fn.len:
      var ch = fn[i].toLowerAscii
      var id = nnkIdentDefs.newTree(ident($ch))
      id.add(nnkVarTy.newTree(typeTable[$ch]))
      id.add(newEmptyNode())
      params.add(id)

    prc.add(params)
    prc.add(newEmptyNode())

    def.add(prc)
    sec.add(def)

  nnkStmtList.newTree(sec)

macro generateSomeFunc() =
  var res = nnkStmtList.newTree()
  var sec = nnkTypeSection.newTree()

  proc idx(vs: seq[string]): NimNode =
    if len(vs) == 1:
      ident(vs[0])
    else:
      nnkInfix.newTree(ident("|"), ident(vs[0]), idx(vs[1..<vs.len]))

  var def = nnkTypeDef.newTree(
    newIdentNode("SomeFunc"),
    newEmptyNode(),
    idx(FUNCTION_NAMES))

  sec.add(def)
  res.add(sec)
  res

macro generateEnum() =
  newEnum(
    name = ident("FunKind"),
    fields = FUNCTION_NAMES.map(
      (f) => f[0] & (f[2..<f.len])
    ).mapIt(ident(it.toLowerAscii)),
    public = false, pure = false)

macro generateObject() =
  var xs = nnkRecCase.newTree(
    nnkIdentDefs.newTree(ident("kind"), ident("FunKind"), newEmptyNode()))
  for f in FUNCTION_NAMES:
    let field = ident((f[0] & (f[2..<f.len])).toLowerAscii)
    xs.add(nnkOfBranch.newTree(
      field,
      nnkIdentDefs.newTree(field, ident(f), newEmptyNode())))
  nnkStmtList.newTree(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        ident("Function"),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          nnkRecList.newTree(xs)))))

macro generateConstructor() =
  var tree = nnkWhenStmt.newTree()
  for f in FUNCTION_NAMES:
    let field = ident((f[0] & (f[2..<f.len])).toLowerAscii)
    tree.add(
      nnkElifBranch.newTree(
        nnkInfix.newTree(ident("is"), ident("f"), ident(f)),
        nnkStmtList.newTree(
          nnkObjConstr.newTree(
            ident("Function"),
            nnkExprColonExpr.newTree(ident("kind"), field),
            nnkExprColonExpr.newTree(field, ident("f"))))))
  nnkStmtList.newTree(
    nnkProcDef.newTree(
      ident("asFun"),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        ident("Function"),
        nnkIdentDefs.newTree(
          ident("f"),
          ident("SomeFunc"),
          newEmptyNode())),
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(tree)))

macro generateCall*() =
  var params = nnkFormalParams.newTree(
    newEmptyNode(),
    nnkIdentDefs.newTree(
      ident("fn"),
      ident("Function"),
      newEmptyNode()))

  for k, v in typeTable:
    params.add(
      nnkIdentDefs.newTree(
        ident(k),
        nnkVarTy.newTree(v),
        newEmptyNode()))

  var cas = nnkCaseStmt.newTree(
    nnkDotExpr.newTree(ident("fn"), ident("kind")))

  for f in FUNCTION_NAMES:
    let id = (f[0] & (f[2..<f.len])).toLowerAscii
    let num = len(id) - 1

    if num == 0:
      cas.add(
        nnkOfBranch.newTree(
          ident(id),
          nnkStmtList.newTree(
            nnkCall.newTree(nnkDotExpr.newTree(ident("fn"), ident(id))))))
    else:
      var call = nnkCall.newTree(
        nnkDotExpr.newTree(ident("fn"), ident(id)))
      for i in 1..<id.len:
        call.add(ident($id[i]))
      cas.add(nnkOfBranch.newTree(ident(id), nnkStmtList.newTree(call)))

  nnkStmtList.newTree(
    nnkProcDef.newTree(
      nnkPostfix.newTree(newIdentNode("*"), newIdentNode("call")),
      newEmptyNode(), newEmptyNode(), params, newEmptyNode(), newEmptyNode(),
      nnkStmtList.newTree(cas)))

generateFunctionTypes()
generateSomeFunc()
generateEnum()
generateObject()
generateConstructor()
generateCall()

## NOTE: on ordering plugins
# I would like to have a system where you can say, this plugin runs after, or before
# this other plugin, this is better then using a number since if you wanted to add a plugin
# you would need to manually update the priority number

## For now though I will use an OrderedTable.

# variant Ordering:
#   Default
#   IsBefore(beforeId: string)
#   IsAfter(afterId: string)

type
  PluginStage* = enum
    load
    update
    draw
    unload

  PluginFunction = tuple[stage: PluginStage, fn: Function]
  Plugin = object
    fs: seq[PluginFunction]
    isScene = false
    hasLoaded = false
    # when not empty, will be active only when scene in seq is active
    activeOnScenes: seq[string] = @[]

  OrderRule = tuple[id: string, isAfter: string, isBefore: string]

  Plugins* = ref object
    plugins: OrderedTable[string, Plugin]

var pluginOrderRules: seq[int] = @[]
# var ordering =

proc pluginIds*(plugins: Plugins): seq[string] =
  result = plugins.plugins.keys.toSeq()

proc impl(ps: Plugins, id: string, stage: PluginStage, f: SomeFunc): Plugins =
  block:
    discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[]))
    ps.plugins[id].fs.add((stage, f.asFun()))
    ps

type PluginAdd = ref object
  id: string
  ps: Plugins

macro generateAdds() =
  result = nnkStmtList.newTree()
  for f in FUNCTION_NAMES:
    let id = ident(f)
    result.add(
      quote do:
      proc add*(ps: Plugins, id: string, stage: PluginStage,
          fun: `id`): Plugins {.discardable.} =
        ps.impl(id, stage, fun))

generateAdds()

# Plugin will only be active when scenes are active
proc activeOnScene*(plugins: Plugins, pluginId: string, scenes: varargs[string]) =
  for id in scenes:
    plugins.plugins[pluginId].activeOnScenes.add(id)

iterator items*(ps: Plugins): (string, Plugin) =
  for k in ps.plugins.keys:
    yield (k, ps.plugins[k])

proc isScene*(p: Plugin): bool = p.isScene

proc isScene*(plugins: Plugins, pluginId: string): bool =
  result = plugins.plugins[pluginId].isScene()

func init*(T: type Plugins): T =
  T(plugins: initOrderedTable[string, Plugin]())

proc isActive(self: Plugins, activeScene: Option[string], id: string): bool =
  let plug = self.plugins[id]

  if plug.isScene:
    return id == activeScene.get("")

  if plug.activeOnScenes.len > 0:
    var active = false
    for sc in plug.activeOnScenes:
      if self.plugins[sc].isScene and sc == activeScene.get(""):
        active = true
        break

    if not active:
      return false

  return true

proc doStage*(self: Plugins, stage: PluginStage, activeScene: Option[
    string], e: var Events, a: var Artist, c: var Commands,
        s: var GameState, n: var Ents) =
  for id in self.plugins.keys:
    var plug = self.plugins[id]

    if not self.isActive(activeScene, id):
      continue

    if plug.isScene and not plug.hasLoaded:
      continue

    for (pluginStage, fn) in plug.fs:
      if pluginStage == stage:
        call(fn, a, c, e, n, s)

proc load*(self: Plugins, id: string, e: var Events, a: var Artist,
    c: var Commands, s: var GameState, n: var Ents) =
  if not self.plugins.hasKey(id):
    return

  var plugin = self.plugins[id]
  plugin.hasLoaded = true
  self.plugins[id] = plugin

  for (stage, fn) in plugin.fs:
    if stage == load:
      info("Loading: " & id)
      call(fn, a, c, e, n, s)

proc update*(self: Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, c: var Commands, s: var GameState, n: var Ents) =
  self.doStage(update, activeScene, e, a, c, s, n)

proc draw*(self: Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, c: var Commands, s: var GameState, n: var Ents) =
  self.doStage(draw, activeScene, e, a, c, s, n)

template plugin*(ps: Plugins, id: string, lod: untyped, upd: untyped,
    drw: untyped): Plugins =
  ps.add(id, load, lod)
    .add(id, update, upd)
    .add(id, draw, drw)

template plugin*(ps: Plugins, id: string, lod: untyped,
    upd: untyped): Plugins =
  ps.add(id, load, lod).add(id, update, upd)

template plugin*(ps: Plugins, id: string, lod: untyped): Plugins =
  ps.add(id, load, lod)

template scene*(ps: Plugins, id: string, lod: untyped, upd: untyped,
    drw: untyped): Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod)
    .add(id, update, upd)
    .add(id, draw, drw)

template scene*(ps: Plugins, id: string, lod: untyped,
    upd: untyped): Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod).add(id, update, upd)

template scene*(ps: Plugins, id: string, lod: untyped): Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod)

when isMainModule:
  proc drawFn(a: var Artist, c: var Commands) =
    discard

  var plugins = Plugins.init()
  plugins.add("test", draw, drawFn)
