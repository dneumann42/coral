import events, plugins, scenes, options, resources
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

proc load(game: var Game) =
  initializeWindow(title = game.title)
  game.scenes.change(Go game.startingScene)

proc update(game: var Game) =
  game.shouldExit = windowShouldClose()

  for loadId in game.scenes.shouldLoad():
    game.plugins.load(loadId, game.events, game.artist, game.resources)

  game.plugins.update(game.events, game.artist, game.resources)

proc draw(game: var Game) =
  artist.withDrawing:
    game.plugins.draw(game.events, game.artist, game.resources)
    game.artist.paint()

proc start*(game: var Game) =
  game.load()
  while not game.shouldExit:
    game.update()
    game.draw()
