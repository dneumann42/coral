import events, options, commands, patty, states, plugins, macros, scenes,
    tables, sets, sequtils, json, typetraits, fusion/matching
import ../artist/[artist, atlas]
import ../entities/ents
import ../platform
import coral/core
import coral/core/profiles

type
  GameStep* = enum
    load
    loadScene
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

proc loadProfile*(game: var Game; profileId: string; cmds: ptr Commands) =
  var profile = Profile(name: profileId)
  var states = profile.load() do (jn: string; js: JsonNode) -> JsonNode:
    genMigrationFun(jn, js, [])
  cmds[] = Commands.load(states[name(Commands)], Commands.version)

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
      SaveProfile:
        if Some(@profile) ?= game.profile:
          saveProfile(profile, [(commands, Commands)])
      LoadProfile(loadId): discard

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
  if result:
    echo "LOADING ", id

proc isActiveAndReady(id: PluginId): bool =
  result = id.isActive() and not id.shouldLoad(keep = true)

template start*(game: var Game) =
  block:
    var
      cmds {.inject.} = Commands.init()
      artist {.inject.} = Artist.init()
      atlas {.inject.} = Atlas.init()
      states {.inject.} = GameState.init()
      ents {.inject.} = Ents.init()
      events {.inject.} = Events.init()
      resources {.inject.} = Resources.init()

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
