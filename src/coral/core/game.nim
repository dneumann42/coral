import events, commands, patty, states, plugins, scenes, fusion/matching, print,
    algorithm, sugar, times
import ../artist/[artist, atlas]
import ../platform
import ../entities/ents

import std/[logging, sets, sequtils, json, typetraits, options, macros, tables]
import coral/core, dynlib, times
import coral/core/[profiles, saving]

export options, dynlib, times

type
  GameStep* = enum
    load
    loadScene
    unloadScene
    update
    persistentUpdate
    draw
    unload
    onEvent

  EntIdIndex* = object
    nextId: int

  Game* = object
    shouldExit: bool
    startingScene: string
    title: string
    name: string
    profile: Option[Profile]

implSavable(EntIdIndex, 1)
implLoadable(EntIdIndex)

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

var isSceneSpecific: Table[PluginId, seq[SceneId]]
var isPaused = false

proc onScene*(pluginId: PluginId; sceneIds: varargs[SceneId]) =
  var ps = isSceneSpecific.mgetOrPut(pluginId, @[])
  for s in sceneIds:
    ps.add(s)
  isSceneSpecific[pluginId] = ps

func resources*(game: var Game): var Resources =
  game.resources

func init*(T: type Game; name: string; startingScene = none(SceneId);
    title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
    name: name)

proc title*(game: Game): string = game.title

proc currentProfile*(game: Game): Option[Profile] =
  game.profile

proc getProfiles*(game: Game): seq[Profile] =
  getProfiles(game.name)

proc deleteProfile*(game: var Game; profileId: string) =
  var profile = Profile(name: profileId, gameName: game.name)
  profile.delete()

proc latestProfile*(game: Game): Option[Profile] =
  var profiles = game.getProfiles()
  if profiles.len() == 0:
    return none(Profile)
  profiles.sort((a, b: Profile) => cmp(b.lastWritten, a.lastWritten))
  profiles[0].some()

proc isActivePersistent(id: PluginId): bool =
  if not isScene(id) and isSceneSpecific.hasKey(id) and isSceneSpecific[
      id].len > 0:
    if sequtils.any(isSceneSpecific[id], isActivePersistent):
      return true
    else:
      return false
  if not isScene(id) or activeScene().isNone:
    return true
  result = activeScene().get("") == id

proc isActive(id: PluginId): bool =
  result = id.isActivePersistent() and not isPaused

proc shouldLoadScene(id: PluginId): bool =
  result = id.isActive() and id.shouldLoad()

proc shouldUnloadScene(id: PluginId): bool =
  result = id.shouldUnload()

proc isActiveAndReady(id: PluginId): bool =
  result = id.isActivePersistent() and not id.shouldLoad(keep = true)

template start*(game: var Game) =
  generateEnts()

  proc loadGameProfile(profileId: string; cmds: ptr Commands;
      js: var JsonNode) =
    var profile = Profile(name: profileId, gameName: game.name)
    var states = profile.load(js) do (jn: string; js: JsonNode) -> JsonNode:
      genMigrationFun(jn, js, [Commands, Ents])
    game.profile = profile.some()
    if states.hasKey(name(Commands)):
      cmds[] = Commands.load(Commands.migrate(states[name(Commands)]))
    discard Ents.load(Ents.migrate(states[name(Ents)]))

  template commandDispatch(commands: var Commands) =
    var commandQueue = commands.toSeq()
    commands.clear()
    template saveGame(profile: Profile) =
      let pluginStates = generateStateSaves()
      saveProfile(profile, [(commands, Commands), (Ents(), Ents)], pluginStates)

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
          profile.saveGame()
          game.profile = some(profile)
          info("Created new profile: " & newId)
        SaveProfile:
          if Some(@profile) ?= game.profile:
            profile.saveGame()
            info("Saved profile: " & profile.name)
        LoadProfile(loadId):
          var js = newJObject()
          loadGameProfile(loadId, commands.addr, js)
          generateStateLoads(js)
          info("Loaded profile: " & loadId)
        PauseGame:
          isPaused = true
        ResumeGame:
          isPaused = false
        DeleteProfile(deleteId):
          game.deleteProfile(deleteId)
          info("Deleted profile: " & deleteId)

  block:
    var
      cmds {.inject, used.} = Commands.init()
      artist {.inject, used.} = Artist.init()
      atlas {.inject, used.} = Atlas.init()
      events {.inject, used.} = Events.init()
      resources {.inject, used.} = Resources.init()

    initializeWindow(title = game.title)
    pushScene(game.startingScene)
    
    generateStates()
    generatePluginStep[GameStep](load)

    while updateWindow():
      if game.shouldExit:
        closeWindow()
        break

      for ev in pollEvents():
        let event {.inject.} = ev
        generatePluginStep[GameStep](onEvent, isActivePersistent)

      if shouldUpdate():
        generateHotloadUpdate()

        generatePluginStep[GameStep](loadScene, shouldLoadScene)
        generatePluginStep[GameStep](update, isActive)
        generatePluginStep[GameStep](persistentUpdate, isActivePersistent)
        generatePluginStep[GameStep](unloadScene, shouldUnloadScene)

      commandDispatch(cmds)
      flushEvents()

      if game.shouldExit:
        closeWindow()
        break

      withDrawing:
        clear(artist)
        generatePluginStep[GameStep](draw, isActiveAndReady)
        paint(artist)
