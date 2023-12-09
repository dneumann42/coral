import events, scenes, options, commands, patty, states, ents, plugins2, macros
import ../artist/artist

import ../platform

type
  GameStep* = enum
    load
    update
    draw
    unload

  Game* = object
    shouldExit: bool
    startingScene: string
    title: string
    state: GameState
    ents: Ents
    events: Events
    scenes: Scenes
    artist: Artist
    resources: Resources

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

func resources*(game: var Game): var Resources =
  game.resources

func state*(game: var Game): var GameState =
  game.state

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
    state: GameState.init(),
    ents: Ents.init(),
    events: Events.init(),
    scenes: Scenes.init(),
    resources: Resources.init())

proc commandDispatch*(game: var Game; commands: Commands) =
  for cmd in commands:
    match cmd:
      Scene(change): game.scenes.change(change)
      Exit: game.shouldExit = true
      SaveProfile: discard

template withCommands(game: var Game; blk: untyped) =
  var commands = Commands.init()
  blk(game, commands)
  game.commandDispatch(commands)

template load(game: var Game) =
  initializeWindow(title = game.title)
  # game.scenes.change(Go game.startingScene)

  proc good(id: string): bool = true
  expandMacros:
    generatePluginSteps[GameStep](load, good)

proc update(game: var Game) =
  # game.withCommands do (game: var Game; cmd: var Commands):
  #   discard

  # game.withCommands do (game: var Game; cmd: var Commands):
  #   discard

  game.events.flush()

proc draw(game: var Game) =
  game.withCommands do (game: var Game; cmd: var Commands):
    game.artist.paint()

template start*(game: var Game) =
  game.load()

  while updateWindow():
    if game.shouldExit:
      closeWindow()
      continue

    if shouldUpdate():
      game.update()

    withDrawing:
      game.draw()
