import events, plugins, scenes, options
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

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

func plugins*(game: var Game): var Plugins =
  game.plugins

func init*(T: type Game; startingScene = none(SceneId); title = ""): T =
  T(startingScene: startingScene.get(""),
    title: title,
    events: Events.init(),
    scenes: Scenes.init())

proc load(game: var Game) =
  initializeWindow(title = game.title)
  game.scenes.change(Go game.startingScene)

proc update(game: var Game) =
  game.shouldExit = windowShouldClose()

  for loadId in game.scenes.shouldLoad():
    game.plugins.load(loadId, game.events)

  game.plugins.update(game.events)

proc draw(game: var Game) =
  artist.withDrawing:
    game.plugins.draw(game.events)
    game.artist.paint()
    rect(100.0, 100.0)

proc start*(game: var Game) =
  game.load()
  while not game.shouldExit:
    game.update()
    game.draw()
