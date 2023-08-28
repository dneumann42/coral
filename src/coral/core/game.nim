import events, plugins, scenes, options, resources, commands, patty
import ../artist/artist

from platform import initializeWindow, windowShouldClose

type
  Game* = object
    shouldExit: bool
    startingScene: string

    title: string

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

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
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

proc update(game: var Game) =
  game.shouldExit = windowShouldClose()

  game.withCommands do (game: var Game; cmd: var Commands):
    for loadId in game.scenes.shouldLoad():
      game.plugins.load(loadId, game.events, game.artist, game.resources, cmd)

  game.withCommands do (game: var Game; cmd: var Commands):
    game.plugins.update(game.scenes.activeScene(), game.events, game.artist,
        game.resources, cmd)

proc draw(game: var Game) =
  artist.withDrawing:
    game.withCommands do (game: var Game; cmd: var Commands):
      game.plugins.draw(game.scenes.activeScene(), game.events, game.artist,
          game.resources, cmd)
      game.artist.paint()

proc start*(game: var Game) =
  game.load()
  while not game.shouldExit:
    game.update()
    game.draw()
