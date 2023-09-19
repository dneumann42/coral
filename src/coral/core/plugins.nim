import std/logging
import sugar, events, tables, patty, options, commands, states
import ../artist/artist

type Fn = () -> void
type FnVE = (var Events) -> void
type FnE = (Events) -> void

type FnC = (var Commands) -> void
type FnS = (var GameState) -> void
type FnCS = (var Commands, var GameState) -> void

type FnA = (var Artist) -> void
type FnAS = (var Artist, var GameState) -> void

type SomeFunc = Fn | FnVE | FnE | FnC | FnS | FnCS | FnA | FnAS

variant Function:
  Fun(f: Fn)
  FunVE(fve: FnVE)
  FunE(fe: FnE)
  FunC(fc: FnC)
  FunS(fs: FnS)
  FunCS(fcs: FnCS)
  FunA(fa: FnA)
  FunAS(fas: FnAS)

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

  Plugins* = object
    plugins: Table[string, Plugin]

# we shouldn't call any functions until we are loaded

iterator items*(ps: Plugins): (string, Plugin) =
  for k in ps.plugins.keys:
    yield (k, ps.plugins[k])

proc isScene*(p: Plugin): bool = p.isScene

func init*(T: type Plugins): T =
  T(plugins: initTable[string, Plugin]())

type PluginAdd = ref object
  id: string
  ps: var Plugins

func asFun(f: SomeFunc): Function =
  when f is Fn: Fun(f)
  elif f is FnVE: FunVE(f)
  elif f is FnE: FunE(f)
  elif f is FnC: FunC(f)
  elif f is FnS: FunS(f)
  elif f is FnCS: FunCS(f)
  elif f is FnA: FunA(f)
  elif f is FnAS: FunAS(f)

proc call*(fn: Function, e: var Events, a: var Artist,
    c: var Commands, s: var GameState) =
  match fn:
    Fun(f): f()
    FunVE(f): f(e)
    FunE(f): f(e)
    FunC(f): f(c)
    FunS(f): f(s)
    FunCS(f): f(c, s)
    FunA(f): f(a)
    FunAS(f): f(a, s)

proc doStage*(self: var Plugins, stage: PluginStage, activeScene: Option[
    string], e: var Events, a: var Artist, c: var Commands,
        s: var GameState) =
  for id in self.plugins.keys:
    var plug = self.plugins[id]

    if plug.isScene and id != activeScene.get(""):
      continue

    if plug.isScene and not plug.hasLoaded:
      continue

    for (pluginStage, fn) in plug.fs:
      if pluginStage == stage:
        call(fn, e, a, c, s)

proc load*(self: var Plugins, id: string, e: var Events, a: var Artist,
    c: var Commands, s: var GameState) =
  if not self.plugins.hasKey(id):
    return

  var plugin = self.plugins[id]
  plugin.hasLoaded = true
  self.plugins[id] = plugin

  for (stage, fn) in plugin.fs:
    if stage == load:
      info("Loading: " & id)
      call(fn, e, a, c, s)

proc update*(self: var Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, c: var Commands, s: var GameState) =
  self.doStage(update, activeScene, e, a, c, s)

proc draw*(self: var Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, c: var Commands, s: var GameState) =
  self.doStage(draw, activeScene, e, a, c, s)

template impl(f: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[]))
  ps.plugins[id].fs.add((stage, f.asFun()))
  ps

proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: Fn): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnVE): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnE): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnC): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnS): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnCS): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnA): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnAS): var Plugins {.discardable.} = impl(f)

template plugin*(ps: var Plugins, id: string, lod: untyped, upd: untyped,
    drw: untyped): var Plugins =
  ps.add(id, load, lod)
    .add(id, update, upd)
    .add(id, draw, drw)

template plugin*(ps: var Plugins, id: string, lod: untyped,
    upd: untyped): var Plugins =
  ps.add(id, load, lod).add(id, update, upd)

template plugin*(ps: var Plugins, id: string, lod: untyped): var Plugins =
  ps.add(id, load, lod)

template scene*(ps: var Plugins, id: string, lod: untyped, upd: untyped,
    drw: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod)
    .add(id, update, upd)
    .add(id, draw, drw)

template scene*(ps: var Plugins, id: string, lod: untyped,
    upd: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod).add(id, update, upd)

template scene*(ps: var Plugins, id: string, lod: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true,
      hasLoaded: false))
  ps.add(id, load, lod)
