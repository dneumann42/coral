import events, options, commands, patty, states, ents, plugins2, macros, scenes
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

func resources*(game: var Game): var Resources =
  game.resources

func state*(game: var Game): var GameState =
  game.state

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title)

proc title*(game: Game): string = game.title

proc commandDispatch*(game: var Game; commands: Commands) =
  for cmd in commands:
    match cmd:
      PushScene(pushId): pushScene(pushId)
      ChangeScene(changeId): discard changeScene(changeId)
      BackScene: discard backScene()
      Exit: game.shouldExit = true
      SaveProfile: discard

template start*(game: var Game) =
  var
    cmds {.inject.} = Commands.init()
    artist {.inject.} = Artist.init()
    state {.inject.} = GameState.init()
    ents {.inject.} = Ents.init()
    events {.inject.} = Events.init()
    resources {.inject.} = Resources.init()

  proc shouldLoadScene(id: PluginId): bool =
    result = shouldLoad(id)

  proc isActive(id: PluginId): bool =
    if not isScene(id) or activeScene().isNone:
      return true
    result = activeScene().get() == id

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
