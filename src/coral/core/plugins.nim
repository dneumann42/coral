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
  Plugin = seq[PluginFunction]
  Plugins* = object
    plugins: Table[string, Plugin]

func init*(T: type Plugins): T =
  T(plugins: initTable[string, Plugin]())

type PluginAdd = ref object
  id: string
  ps: var Plugins

proc plugin*(ps: var Plugins, id: string): PluginAdd {.discardable.} =
  PluginAdd(id: id, ps: ps)

template load*(p: PluginAdd, fn: untyped): PluginAdd =
  p.ps.add(p.id, load, fn)
  p

template update*(p: PluginAdd, fn: untyped): PluginAdd =
  p.ps.add(p.id, update, fn)
  p

template draw*(p: PluginAdd, fn: untyped): PluginAdd =
  p.ps.add(p.id, draw, fn)
  p

template done*(pa: PluginAdd): var Plugins =
  pa.ps

func asFun(f: Fn | FnVE | FnE): Function =
  when f is Fn: Fun(f)
  elif f is FnVE: FunVE(f)
  elif f is FnE: FunE(f)

proc call*(fn: Function, e: var Events) =
  match fn:
    Fun(f): f()
    FunVE(f): f(e)
    FunE(f): f(e)

proc update*(self: var Plugins, e: var Events) =
  for plug in self.plugins.values:
    for (stage, fn) in plug:
      if stage != update:
        continue
      call(fn, e)

proc draw*(self: Plugins, e: var Events) =
  for plug in self.plugins.values:
    for (stage, fn) in plug:
      if stage != draw:
        continue
      call(fn, e)

template impl() =
  discard ps.plugins.hasKeyOrPut(id, @[])
  ps.plugins[id].add((stage, f.asFun()))

proc add*(ps: var Plugins, id: string, stage: PluginStage, f: Fn) = impl()
proc add*(ps: var Plugins, id: string, stage: PluginStage, f: FnVE) = impl()
proc add*(ps: var Plugins, id: string, stage: PluginStage, f: FnE) = impl()
