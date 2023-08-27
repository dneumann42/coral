import platform

type
  Game* = object
    shouldExit: bool
    title: string

proc `=sink`(x: var Game; y: Game) {.error.}
proc `=copy`(x: var Game; y: Game) {.error.}
proc `=wasMoved`(x: var Game) {.error.}

func init*(T: type Game; title = ""): T =
  T(title: title)

proc load(game: var Game) =
  initializeWindow(title = game.title)

proc update(game: var Game) =
  game.shouldExit = windowShouldClose()
  discard

proc draw(game: var Game) =
  withDrawing:
    discard

func start*(game: var Game) =
  game.load()

  while not game.shouldExit:
    game.update()
    game.draw()
