import sequtils, std/logging
import sdl2/[image, gfx, ttf]
import sdl2, hashes, tables, os, state

proc extractFilenameWithoutExt*(path: string): string =
  let subpath = extractFilename(path)
  result = subpath.substr(0, searchExtPos(subpath) - 1)

type
  Texture* = object
    texture: TexturePtr
  Font* = object
    font: FontPtr
  Resources* = object
    fonts: Table[string, Font]
    textures: Table[string, Texture]

proc init*(T: type Resources): T =
  T(textures: initTable[string, Texture](),
    fonts: initTable[string, Font](), )

proc init*(T: type Texture, tptr: TexturePtr): T =
  T(texture: tptr)

proc load*(T: type Texture, path: string): T =
  var tex = getRenderer().loadTexture(path.cstring)
  if tex.isNil:
    return
  T(texture: tex)

proc load*(T: type Font, path: string, size: int): T =
  var fnt = openFont(path.cstring, size.cint)
  if fnt.isNil:
    echo getError()
    return
  T(font: fnt)

proc load*(res: var Resources, T: type Texture, path, id: string) =
  info("Loading texture " & id & "...")
  res.textures[id] = T.load(path)

proc load*(res: var Resources, T: type Font, path, id: string, size: int) =
  info("Loading font " & id & "...")
  res.fonts[id] = T.load(path, size)

proc get*(res: var Resources, T: type Texture, id: string): T =
  res.textures[id]

proc get*(res: var Resources, T: type Font, id: string): T =
  res.fonts[id]

proc texPtr*(t: Texture): TexturePtr =
  t.texture

proc fontPtr*(t: Font): FontPtr =
  t.font

proc size*(t: Texture): (float, float) =
  var w, h: cint
  queryTexture(t.texPtr, nil, nil, w.addr, h.addr)
  result = (w.float, h.float)

proc width*(t: Texture): float =
  result = t.size()[0]

proc height*(t: Texture): float =
  result = t.size()[1]

proc `delete=`*(tex: Texture) =
  destroyTexture(tex.texture)
