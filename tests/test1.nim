import coral/[core, platform, ents]
import menuscene, gamescene

proc `%`*(e: EntId): JsonNode =
  result.add( % (e.int))

type X = object
implSaveLoad(X, 1)

registerComponents:
  X

when isMainModule:
  var game = Game.init(
    "Apothecary",
    none(string),
    title = "Apothecary - version 0.0.0"
  )

  setPriority("Hotload", 1001)
  setPriority("Resources", 1000)
  start(game)
