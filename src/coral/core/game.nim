import events, commands, patty, states, plugins, scenes, fusion/matching, print,
    algorithm, sugar, times
import ../artist/[artist, atlas]
import ../entities/ents
import ../platform

import std/[logging, sets, sequtils, json, typetraits, options, macros, tables]
import coral/core
import coral/core/profiles

export options

type
  GameStep* = enum
    load
    loadScene
    unloadScene
    update
    draw
    unload

  Game* = object
    shouldExit: bool
    startingScene: string
    title: string
    name: string
    profile: Option[Profile]

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

var isSceneSpecific: Table[PluginId, seq[SceneId]]

proc onScene*(pluginId: PluginId; sceneId: SceneId) =
  isSceneSpecific[pluginId] = isSceneSpecific.mgetOrPut(pluginId, @[]).concat(@[sceneId])

func resources*(game: var Game): var Resources =
  game.resources

func state*(game: var Game): var GameState =
  game.state

func init*(T: type Game; name: string; startingScene = none(SceneId);
    title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
    name: name)

proc title*(game: Game): string = game.title

proc currentProfile*(game: Game): Option[Profile] =
  game.profile

proc loadProfile*(game: var Game; profileId: string; cmds: ptr Commands) =
  var profile = Profile(name: profileId, gameName: game.name)
  var states = profile.load() do (jn: string; js: JsonNode) -> JsonNode:
    genMigrationFun(jn, js, [])
  game.profile = profile.some()
  cmds[] = Commands.load(states[name(Commands)], Commands.version)

proc deleteProfile*(game: var Game; profileId: string) =
  var profile = Profile(name: profileId, gameName: game.name)
  profile.delete()

proc getProfiles*(game: Game): seq[Profile] =
  getProfiles(game.name)

proc latestProfile*(game: Game): Option[Profile] =
  var profiles = game.getProfiles()
  if profiles.len() == 0:
    return none(Profile)
  profiles.sort((a, b: Profile) => cmp(b.lastWritten, a.lastWritten))
  profiles[0].some()

proc commandDispatch*(game: var Game; commands: var Commands) =
  var commandQueue = commands.toSeq()
  commands.clear()
  for cmd in commandQueue:
    match cmd:
      PushScene(pushId):
        pushScene(pushId)
      ChangeScene(changeId):
        discard changeScene(changeId)
      BackScene:
        discard backScene()
      Exit:
        game.shouldExit = true
      NewProfile(newId):
        let profile = Profile(name: newId, gameName: game.name)
        saveProfile(profile, [(commands, Commands)])
        game.profile = some(profile)
        info("Created new profile: " & newId)
      SaveProfile:
        if Some(@profile) ?= game.profile:
          saveProfile(profile, [(commands, Commands)])
          info("Saved profile: " & profile.name)
      LoadProfile(loadId):
        game.loadProfile(loadId, commands.addr)
        info("Loaded profile: " & loadId)
      DeleteProfile(deleteId):
        game.deleteProfile(deleteId)
        info("Deleted profile: " & deleteId)

proc isActive(id: PluginId): bool =
  if not isScene(id) and isSceneSpecific.hasKey(id) and isSceneSpecific[
      id].len > 0:
    if sequtils.any(isSceneSpecific[id], isActive):
      return true
    else:
      return false
  if not isScene(id) or activeScene().isNone:
    return true
  result = activeScene().get("") == id

proc shouldLoadScene(id: PluginId): bool =
  result = id.isActive() and id.shouldLoad()

proc isActiveAndReady(id: PluginId): bool =
  result = id.isActive() and not id.shouldLoad(keep = true)

template start*(game: var Game) =
  block:
    var
      cmds {.inject, used.} = Commands.init()
      artist {.inject, used.} = Artist.init()
      atlas {.inject, used.} = Atlas.init()
      states {.inject, used.} = GameState.init()
      ents {.inject, used.} = Ents.init()
      events {.inject, used.} = Events.init()
      resources {.inject, used.} = Resources.init()

    initializeWindow(title = game.title)
    pushScene(game.startingScene)
    generatePluginStep[GameStep](load)

    while updateWindow():
      if game.shouldExit:
        closeWindow()
        break

      if shouldUpdate():
        generatePluginStep[GameStep](loadScene, shouldLoadScene)
        generatePluginStep[GameStep](update, isActive)

      game.commandDispatch(cmds)
      flush(events)

      if game.shouldExit:
        closeWindow()
        break

      withDrawing:
        clear(artist)
        generatePluginStep[GameStep](draw, isActiveAndReady)
        paint(artist)
