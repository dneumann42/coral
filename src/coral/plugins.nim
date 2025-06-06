import std / [ typetraits, algorithm, sugar ]

from clock import Clock
from drawing import Artist, Canvas

import messages
import appcommands

export messages

type
  Plugin* = ref object of RootObj
    id*: string
    commands: seq[Command]

method load* (self: Plugin): void {.base.} = discard
method unload* (self: Plugin): void {.base.} = discard
method update* (self: Plugin, clock: Clock): void {.base.} = discard
method updateAlways* (self: Plugin, clock: Clock): void {.base.} = discard
method preRender* (self: Plugin, artist: var Artist): void {.base.} = discard
method render* (self: Plugin, artist: Artist): void {.base.} = discard
method isScene* (self: Plugin): bool {.base.} = false
method priority* (self: Plugin): int {.base.} = 0
method onMessage* (self: Plugin, msg: AbstractMessage): void {.base.} =
  discard

type
  CanvasPlugin* = ref object of Plugin
    canvas*: Canvas

  ScenePlugin* = ref object of CanvasPlugin

  ClosurePlugin* = ref object of Plugin
    closure: proc(): void {.closure.}

method isScene* (self: ScenePlugin): bool = true

iterator cmds* (plugin: Plugin): Command =
  for cmd in plugin.commands:
    yield cmd

proc invoke* (plugin: ClosurePlugin) =
  plugin.closure()

proc reset* (plugin: Plugin) =
  plugin.commands.setLen(0)

proc push* (plugin: Plugin, id: string) =
  plugin.commands.add(Command(kind: pushScene, pushId: id))

proc goto* (plugin: Plugin, id: string) =
  plugin.commands.add(Command(kind: gotoScene, gotoId: id))

proc pop* (plugin: Plugin) =
  plugin.commands.add(Command(kind: popScene))

proc emit* [M: AbstractMessage] (plugin: Plugin, msg: M) =
  plugin.commands.add(
    Command(kind: emit, msg: msg.AbstractMessage))

type
  Plugins* = object
    plugins: seq[Plugin]
    closurePlugins: seq[ClosurePlugin]

proc sortPlugins* (plugins: var Plugins) =
  plugins.plugins.sort(proc(a, b: Plugin): int = cmp(b.priority(), a.priority()))

proc add* [T: Plugin] (ps: var Plugins, p: T) =
  var p2 = p
  p2.id = T.sceneId()
  ps.plugins.add(p2)

proc add* (ps: var Plugins, c: proc(): void {.closure.}) =
  ps.closurePlugins.add(ClosurePlugin(closure: c))

proc sceneId* (T: typedesc): string = T.name

iterator plugins* (ps: Plugins): auto =
  for plug in ps.plugins.items:
    yield plug

iterator closurePlugins* (ps: Plugins): auto =
  for plug in ps.closurePlugins.items:
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
