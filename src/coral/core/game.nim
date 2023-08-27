import platform, events, plugins

type
  Game* = object
    shouldExit: bool
    title: string
    plugins: Plugins
    events: Events

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

func plugins*(game: var Game): var Plugins =
  game.plugins

func init*(T: type Game; title = ""): T =
  T(title: title, events: Events.init())

proc load(game: var Game) =
  initializeWindow(title = game.title)

proc update(game: var Game) =
  game.shouldExit = windowShouldClose()
  game.plugins.update(game.events)

proc draw(game: var Game) =
  withDrawing:
    game.plugins.draw(game.events)

proc start*(game: var Game) =
  game.load()

  while not game.shouldExit:
    game.update()
    game.draw()
