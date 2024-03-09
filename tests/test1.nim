import coral/[core, platform, ents, artist]
import vmath
import menuscene, gamescene

proc `%`*(e: EntId): JsonNode =
  result.add( % (e.int))

type X = object
implSaveLoad(X, 1)

registerComponents:
  X

plugin TextDemo:
  proc load() =
    loadFont("tests/DungeonFont.ttf", "text", 32)

  proc draw(artist: var Artist) =
    drawText("""
Lorem ipsum dolor sit amet, officia excepteur ex fugiat reprehenderit enim labore culpa sint ad nisi Lorem pariatur mollit ex esse exercitation amet. Nisi anim cupidatat excepteur officia. Reprehenderit nostrud nostrud ipsum Lorem est aliquip amet voluptate voluptate dolor minim nulla est proident. Nostrud officia pariatur ut officia. Sit irure elit esse ea nulla sunt ex occaecat reprehenderit commodo officia dolor Lorem duis laboris cupidatat officia voluptate. Culpa proident adipisicing id nulla nisi laboris ex in Lorem sunt duis officia eiusmod. Aliqua reprehenderit commodo ex non excepteur duis sunt velit enim. Voluptate laboris sint cupidatat ullamco ut ea consectetur et est culpa et culpa duis.
    """, "text", vec2(0.0, 0.0), color = White, breakX = 500)

when isMainModule:
  var game = Game.init(
    "Apothecary",
    none(string),
    title = "Apothecary - version 0.0.0"
  )

  setPriority("Hotload", 1001)
  setPriority("Resources", 1000)
  start(game)
