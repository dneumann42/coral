discard """
plugin GameScene(GameState):
  proc load() =
    # self is of-type GameState
    discard

  proc update() =
    discard

  proc render() =
    discard
"""

import std / [ macros, macrocache, tables, options ]

type 
  AbstractPlugin* = ref object of RootObj

  LoadProcVoid = proc(): void
  UpdateProcVoid = proc(): void
  RenderProcVoid = proc(): void

  Plugin* [T] = ref object of AbstractPlugin
    when T isnot void:
      state: T
    load: LoadProcVoid = nil
    update: UpdateProcVoid = nil
    render: RenderProcVoid = nil

  Plugins* = object
    plugins: Table[string, AbstractPlugin]

const PluginCtors* = CacheSeq"PluginCtors"
const PluginIds* = CacheSeq"PluginIds"

proc init* (T: type Plugins): T =
  result = T(
    plugins: initTable(string, AbstractPlugin)
  )

proc addPlugin* [T](plugins: var Plugins, id: string, plugin: Plugin[T]) =
  plugins.plugins[id] = cast[AbstractPlugin](plugin)

macro plugin* (x, y: untyped): auto =
  let id = if x.kind == nnkCall: x[0] else: x
  let st = if x.len > 1: x[1] else: ident"void"

  let funcName = ident("init" & id.repr)
  PluginCtors.add(funcName)
  PluginIds.add(id)

  let state = 
    if x.kind == nnkCall and x.len > 1:
      nnkObjConstr.newTree(nnkBracketExpr.newTree(ident("Plugin"), st),
        nnkExprColonExpr.newTree(ident("state"), nnkCall.newTree(ident("default"), st)))
    else:
      nnkObjConstr.newTree(nnkBracketExpr.newTree(ident("Plugin"), st))

  var 
    renderN = quote: discard
    updateN = quote: discard
    loadN = quote: discard

  for n in y:
    if n.kind == nnkProcDef:
      if $n[0] == "render": renderN = quote: result.render = render
      if $n[0] == "update": updateN = quote: result.update = update
      if $n[0] == "load": loadN = quote: result.load = load

  let commonStmts = quote do:
    `y` 
    `loadN`
    `updateN`
    `renderN`

  if x.kind != nnkCall or x.len == 1:
    quote do:
      proc `funcName`(): Plugin[void] =
        result = Plugin[void]()
        `commonStmts`
      export `funcName`
  else:
    quote do:
      proc `funcName`(): Plugin[`st`] =
        result = `state`
        var self {.inject.} = result.state
        `commonStmts`
      export `funcName`

when isMainModule:
  expandMacros:
    type GameState = object
      counter = 0

    plugin GameScene(GameState):
      proc update() =
        self.counter += 1

      # proc render(state: GameState) =
      #   discard
