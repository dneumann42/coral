import chroma, macros, strutils, std/enumutils

export chroma

type
  Palette* = enum
    black = "1a1c2c"
    purple = "5d275d"
    red = "b13e53"
    orange = "ef7d57"
    yellow = "ffcd75"
    lightGreen = "a7f070"
    green = "38b764"
    darkGreen = "257179"
    slateBlue = "29366f"
    blue = "3b5dc9"
    lightBlue = "41a6f6"
    skyBlue = "73eff7"
    softWhite = "f4f4f4"
    white = "ffffff"
    lightGray = "94b0c2"
    gray = "566c86"
    slateGray = "333c57"

macro generateConstants(): untyped =
  result = nnkStmtList.newTree()
  for k in Palette.items:
    let id = ident((k.symbolName).capitalizeAscii)
    result.add(
      quote do: 
        const `id`* = parseHex($`k`))

# expandMacros:
generateConstants()