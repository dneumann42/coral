type
  Plugin* = ref object of RootObj

method load* (self: Plugin): void {.base.} = discard
method unload* (self: Plugin): void {.base.} = discard
method update* (self: Plugin): void {.base.} = discard
method render* (self: Plugin): void {.base.} = discard
method isScene* (self: Plugin): bool {.base.} = false

type
  Plugins* = object
    plugins: seq[Plugin]

proc add*(ps: var Plugins, p: Plugin) = ps.plugins.add(p)

iterator plugins* (ps: Plugins): auto =
  for plug in ps.plugins.items:
    yield plug

iterator mplugins* (ps: var Plugins): var auto =
  for plug in ps.plugins.mitems:
    yield plug

iterator scenes* (ps: Plugins): auto =
  for plug in ps.plugins.items:
    if plug.isScene():
      continue
    yield plug

iterator mscenes* (ps: var Plugins): var auto =
  for plug in ps.plugins.mitems:
    if plug.isScene():
      continue
    yield plug
