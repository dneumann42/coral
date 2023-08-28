import sugar, events, tables, patty, resources, options, commands, states
import ../artist/artist

type Fn = () -> void
type FnVE = (var Events) -> void
type FnE = (Events) -> void

type FnR = (Resources) -> void
type FnVR = (var Resources) -> void

type FnC = (var Commands) -> void
type FnS = (var GameState) -> void
type FnCS = (var Commands, var GameState) -> void

type FnAR = (Artist, Resources) -> void
type FnVAR = (var Artist, var Resources) -> void

type SomeFunc = Fn | FnVE | FnE | FnR | FnAR | FnVAR | FnC | FnS | FnCS

variant Function:
  Fun(f: Fn)
  FunVE(fve: FnVE)
  FunE(fe: FnE)
  FunR(fr: FnR)
  FunAR(far: FnAR)
  FunVAR(fvar: FnVAR)
  FunC(fc: FnC)
  FunS(fs: FnS)
  FunCS(fcs: FnCS)

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

  Plugins* = object
    plugins: Table[string, Plugin]

func init*(T: type Plugins): T =
  T(plugins: initTable[string, Plugin]())

type PluginAdd = ref object
  id: string
  ps: var Plugins

func asFun(f: SomeFunc): Function =
  when f is Fn: Fun(f)
  elif f is FnVE: FunVE(f)
  elif f is FnE: FunE(f)
  elif f is FnR: FunR(f)
  elif f is FnAR: FunAR(f)
  elif f is FnVAR: FunVAR(f)
  elif f is FnC: FunC(f)
  elif f is FnS: FunS(f)
  elif f is FnCS: FunCS(f)

proc call*(fn: Function, e: var Events, a: var Artist, r: var Resources,
    c: var Commands, s: var GameState) =
  match fn:
    Fun(f): f()
    FunVE(f): f(e)
    FunE(f): f(e)
    FunR(f): f(r)
    FunAR(f): f(a, r)
    FunVAR(f): f(a, r)
    FunC(f): f(c)
    FunS(f): f(s)
    FunCS(f): f(c, s)

proc doStage*(self: var Plugins, stage: PluginStage, activeScene: Option[
    string], e: var Events, a: var Artist, r: var Resources, c: var Commands,
        s: var GameState) =
  for id in self.plugins.keys:
    var plug = self.plugins[id]
    if plug.isScene and id != activeScene.get(""):
      continue
    for (stage, fn) in plug.fs:
      if stage == stage:
        call(fn, e, a, r, c, s)

proc load*(self: var Plugins, id: string, e: var Events, a: var Artist,
    r: var Resources, c: var Commands, s: var GameState) =
  if not self.plugins.hasKey(id):
    return
  for (stage, fn) in self.plugins[id].fs:
    if stage == load:
      call(fn, e, a, r, c, s)

proc update*(self: var Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, r: var Resources, c: var Commands, s: var GameState) =
  self.doStage(update, activeScene, e, a, r, c, s)

proc draw*(self: var Plugins, activeScene: Option[string], e: var Events,
    a: var Artist, r: var Resources, c: var Commands, s: var GameState) =
  self.doStage(draw, activeScene, e, a, r, c, s)

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
    f: FnR): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnAR): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnVAR): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnC): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnS): var Plugins {.discardable.} = impl(f)
proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnCS): var Plugins {.discardable.} = impl(f)

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
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true))
  ps.add(id, load, lod)
    .add(id, update, upd)
    .add(id, draw, drw)

template scene*(ps: var Plugins, id: string, lod: untyped,
    upd: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true))
  ps.add(id, load, lod).add(id, update, upd)

template scene*(ps: var Plugins, id: string, lod: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[], isScene: true))
  ps.add(id, load, lod)
