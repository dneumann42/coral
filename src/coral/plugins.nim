import std / [ typetraits ]

from drawing import Artist, Canvas
import appcommands

type
  Plugin* = ref object of RootObj
    id*: string
    commands: seq[Command]

method load* (self: Plugin): void {.base.} = discard
method unload* (self: Plugin): void {.base.} = discard
method update* (self: Plugin): void {.base.} = discard
method render* (self: Plugin, artist: Artist): void {.base.} = discard
method isScene* (self: Plugin): bool {.base.} = false

type 
  ScenePlugin* = ref object of Plugin
    canvas*: Canvas

method isScene* (self: ScenePlugin): bool = true

iterator cmds* (plugin: Plugin): Command =
  for cmd in plugin.commands:
    yield cmd

proc reset* (plugin: Plugin) =
  plugin.commands.setLen(0)

proc push* (plugin: Plugin, id: string) =
  plugin.commands.add(Command(kind: pushScene, pushId: id))

proc goto* (plugin: Plugin, id: string) =
  plugin.commands.add(Command(kind: gotoScene, gotoId: id))

proc pop* (plugin: Plugin, id: string) =
  plugin.commands.add(Command(kind: popScene))

type
  Plugins* = object
    plugins: seq[Plugin]

proc add* [T: Plugin] (ps: var Plugins, p: T) = 
  var p2 = p
  p2.id = T.sceneId()
  ps.plugins.add(p2)

proc sceneId* (T: typedesc): string = T.name

iterator plugins* (ps: Plugins): auto =
  for plug in ps.plugins.items:
    yield plug

iterator mplugins* (ps: var Plugins): var Plugin =
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
