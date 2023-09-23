import std/logging, strutils, sequtils, tables
import sugar, events, tables, patty, options, commands, states, ents
import ../artist/artist

import std/macros
import std/macrocache

import fusion/matching
{.experimental: "caseStmtMacros".}

type Fn = () -> void
type FnE = (var Events) -> void

type FnC = (var Commands) -> void
type FnS = (var GameState) -> void
type FnCS = (var Commands, var GameState) -> void

type FnA = (var Artist) -> void
type FnAS = (var Artist, var GameState) -> void

type FnAN = (var Artist, var Ents) -> void
type FnASN = (var Artist, var GameState, var Ents) -> void

type FnN = (var Ents) -> void
type FnCN = (var Commands, var Ents) -> void
type FnSN = (var GameState, var Ents) -> void
type FnCSN = (var Commands, var GameState, var Ents) -> void

type SomeFunc = Fn | FnE | FnC | FnS | FnCS | FnA | FnAS | FnAN | FnASN | FnN | FnCN | FnSN | FnCSN

const typeTable = CacheTable"typeTable"

const FUNCTION_LITERALS = [
  "Fn", "FnE", "FnC", "FnS", "FnCS", "FnA", "FnAS", "FnAN", "FnASN", "FnN", "FnCN", "FnSN", "FnCSN"
]

static:
  typeTable["a"] = ident("Artist")
  typeTable["e"] = ident("Events")
  typeTable["s"] = ident("GameState")
  typeTable["c"] = ident("Commands")
  typeTable["n"] = ident("Ents")

macro generateEnum() =
  newEnum(
    name = ident("FunKind"),
    fields = FUNCTION_LITERALS.map(
      (f) => f[0] & (f[2..<f.len])
    ).mapIt(ident(it.toLowerAscii)),
    public = false, pure = false)

macro generateObject() =
  var xs = nnkRecCase.newTree(
    nnkIdentDefs.newTree(ident("kind"), ident("FunKind"), newEmptyNode()))
  for f in FUNCTION_LITERALS:
    let field = ident((f[0] & (f[2..<f.len])).toLowerAscii)
    xs.add(nnkOfBranch.newTree(
      field,
      nnkIdentDefs.newTree(field, ident(f), newEmptyNode())))
  nnkStmtList.newTree(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        newIdentNode("Function"),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          nnkRecList.newTree(xs)))))

macro generateConstructor() =
  var tree = nnkWhenStmt.newTree()
  for f in FUNCTION_LITERALS:
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
      newIdentNode("fn"),
      newIdentNode("Function"),
      newEmptyNode()))

  for k, v in typeTable:
    params.add(
      nnkIdentDefs.newTree(
        newIdentNode(k),
        nnkVarTy.newTree(v),
        newEmptyNode()))

  var cas = nnkCaseStmt.newTree(
    nnkDotExpr.newTree(
      newIdentNode("fn"),
      newIdentNode("kind")))

  for f in FUNCTION_LITERALS:
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
      newEmptyNode(),
      newEmptyNode(),
      params,
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(cas)))

generateEnum()
generateObject()
generateConstructor()
generateCall()

type
  PluginStage* = enum
    load
    update
    draw
    unload

  PluginFunction = tuple[stage: PluginStage, fn: Function]
  Plugin = object
    fs: seq[PluginFunction]
    isScene: bool
    hasLoaded: bool

  Plugins* = ref object
    plugins: Table[string, Plugin]

proc impl[T](ps: Plugins, id: string, stage: PluginStage, f: T): Plugins =
  block:
    discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[]))
    ps.plugins[id].fs.add((stage, f.asFun()))
    ps

type PluginAdd = ref object
  id: string
  ps: Plugins

macro generateAdds() =
  result = nnkStmtList.newTree()
  for f in FUNCTION_LITERALS:
      result.add nnkProcDef.newTree(
        nnkPostfix.newTree(ident("*"), ident("add")),
        newEmptyNode(),
        newEmptyNode(),
        nnkFormalParams.newTree(
          ident("Plugins"),
          nnkIdentDefs.newTree(ident("ps"), ident("Plugins"), newEmptyNode()),
          nnkIdentDefs.newTree(ident("id"), ident("string"), newEmptyNode()),
          nnkIdentDefs.newTree(ident("stage"), ident("PluginStage"), newEmptyNode()),
          nnkIdentDefs.newTree(ident("f"), ident(f), newEmptyNode())),
        nnkPragma.newTree(ident("discardable")),
        newEmptyNode(),
        nnkStmtList.newTree(
          nnkCall.newTree(ident("impl"), ident("ps"), ident("id"), ident("stage"), ident("f"))))
    
generateAdds()

iterator items*(ps: Plugins): (string, Plugin) =
  for k in ps.plugins.keys:
    yield (k, ps.plugins[k])

proc isScene*(p: Plugin): bool = p.isScene

func init*(T: type Plugins): T =
  T(plugins: initTable[string, Plugin]())

proc doStage*(self: Plugins, stage: PluginStage, activeScene: Option[
    string], e: var Events, a: var Artist, c: var Commands,
        s: var GameState, n: var Ents) =
  for id in self.plugins.keys:
    var plug = self.plugins[id]

    if plug.isScene and id != activeScene.get(""):
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
