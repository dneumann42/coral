import events, options, commands, patty, states, ents, plugins2, macros, scenes,
    tables, sets, sequtils
import ../artist/artist
import ../platform

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

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title)

proc title*(game: Game): string = game.title

proc commandDispatch*(game: var Game; commands: var Commands) =
  for cmd in commands:
    match cmd:
      PushScene(pushId): pushScene(pushId)
      ChangeScene(changeId): discard changeScene(changeId)
      BackScene: discard backScene()
      Exit: game.shouldExit = true
      SaveProfile: discard
  commands.clear()

template start*(game: var Game) =
  block:
    var
      cmds {.inject.} = Commands.init()
      artist {.inject.} = Artist.init()
      states {.inject.} = GameState.init()
      ents {.inject.} = Ents.init()
      events {.inject.} = Events.init()
      resources {.inject.} = Resources.init()

    proc isActive(id: PluginId): bool =
      if not isScene(id) and isSceneSpecific.hasKey(id) and isSceneSpecific[
          id].len > 0:
        if sequtils.any(isSceneSpecific[id], isActive):
          return true
        else:
          return false
      if not isScene(id) or activeScene().isNone:
        return true
      result = activeScene().get() == id

    proc shouldLoadScene(id: PluginId): bool =
      result = shouldLoad(id) and isActive(id)

    initializeWindow(title = game.title)
    pushScene(game.startingScene)
    generatePluginStep[GameStep](load)

    while updateWindow():
      if game.shouldExit:
        closeWindow()
        continue

      if shouldUpdate():
        generatePluginStep[GameStep](loadScene, shouldLoadScene)
        generatePluginStep[GameStep](update, isActive)

      game.commandDispatch(cmds)
      flush(events)

      withDrawing:
        generatePluginStep[GameStep](draw, isActive)
        paint(artist)
