import sugar, events, tables, patty

type Fn = () -> void
type FnVE = (var Events) -> void
type FnE = (Events) -> void

type Func = Fn | FnVE

variant Function:
  Fun(f: Fn)
  FunVE(fve: FnVE)
  FunE(fe: FnE)

type
  PluginStage* = enum
    load
    update
    draw
    unload

  PluginFunction = tuple[stage: PluginStage, fn: Function]
  Plugin = object
    fs: seq[PluginFunction]

  Plugins* = object
    plugins: Table[string, Plugin]

func init*(T: type Plugins): T =
  T(plugins: initTable[string, Plugin]())

type PluginAdd = ref object
  id: string
  ps: var Plugins

func asFun(f: Fn | FnVE | FnE): Function =
  when f is Fn: Fun(f)
  elif f is FnVE: FunVE(f)
  elif f is FnE: FunE(f)

proc call*(fn: Function, e: var Events) =
  match fn:
    Fun(f): f()
    FunVE(f): f(e)
    FunE(f): f(e)

proc load*(self: var Plugins, id: string, e: var Events) =
  if not self.plugins.hasKey(id):
    return
  for (stage, fn) in self.plugins[id].fs:
    if stage == load:
      call(fn, e)

proc update*(self: var Plugins, e: var Events) =
  for plug in self.plugins.values:
    for (stage, fn) in plug.fs:
      if stage == update:
        call(fn, e)

proc draw*(self: Plugins, e: var Events) =
  for plug in self.plugins.values:
    for (stage, fn) in plug.fs:
      if stage == draw:
        call(fn, e)

template impl(f: untyped): var Plugins =
  discard ps.plugins.hasKeyOrPut(id, Plugin(fs: @[]))
  echo id, " ", stage
  ps.plugins[id].fs.add((stage, f.asFun()))
  ps

proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: Fn): var Plugins {.discardable.} = impl(f)

proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnVE): var Plugins {.discardable.} = impl(f)

proc add*(ps: var Plugins, id: string, stage: PluginStage,
    f: FnE): var Plugins {.discardable.} = impl(f)

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
