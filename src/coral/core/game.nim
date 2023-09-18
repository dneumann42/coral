import events, plugins, scenes, options, commands, patty, states
import ../artist/artist

import ../platform/application
import ../platform/resources

type
  Game* = object
    shouldExit: bool
    startingScene: string

    title: string

    state: GameState
    events: Events
    plugins: Plugins
    scenes: Scenes
    artist: Artist
    resources: Resources

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

func plugins*(game: var Game): var Plugins =
  game.plugins

func resources*(game: var Game): var Resources =
  game.resources

func state*(game: var Game): var GameState =
  game.state

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
    state: GameState.init(),
    events: Events.init(),
    scenes: Scenes.init(),
    resources: Resources.init())

proc commandDispatch*(game: var Game; commands: Commands) =
  for cmd in commands:
    match cmd:
      Scene(change): game.scenes.change(change)
      Emit(event): game.events.emit(event)
      Exit: game.shouldExit = true
      SaveProfile: discard

template withCommands(game: var Game; blk: untyped) =
  var commands = Commands.init()
  blk(game, commands)
  game.commandDispatch(commands)

proc load(game: var Game) =
  initializeWindow(title = game.title)
  game.scenes.change(Go game.startingScene)

  game.withCommands do (game: var Game; cmd: var Commands):
    for (id, plugin) in game.plugins:
      if not plugin.isScene:
          game.plugins.load(id, game.events, game.artist, cmd, game.state)

proc update(game: var Game) =
  game.withCommands do (game: var Game; cmd: var Commands):
    for loadId in game.scenes.shouldLoad():
      game.plugins.load(loadId, game.events, game.artist, cmd, game.state)

  game.withCommands do (game: var Game; cmd: var Commands):
    game.plugins.update(game.scenes.activeScene(), game.events, game.artist, cmd, game.state)

proc draw(game: var Game) =
  game.withCommands do (game: var Game; cmd: var Commands):
    game.plugins.draw(game.scenes.activeScene(), game.events, game.artist, cmd, game.state)
    game.artist.paint()

proc start*(game: var Game) =
  game.load()
  while updateWindow():
    game.update()
    withDrawing:
      game.draw()
