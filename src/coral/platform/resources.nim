import sdl2/[image, gfx]
import sdl2, hashes, tables, os, state

proc extractFilenameWithoutExt(path: string): string =
  let subpath = extractFilename(path)
  result = subpath.substr(0, searchExtPos(subpath) - 1)

type
  Texture* = object
    texture: TexturePtr
  TextureId* = distinct string
  Resources* = object
    textures: Table[TextureId, Texture]

proc init*(T: type Resources): T =
  T(textures: initTable[TextureId, Texture]())
 
proc init*(T: type Texture, tptr: TexturePtr): T =
  T(texture: tptr)

proc load*(T: type Texture, path: string): Texture =
  var tex = getRenderer().loadTexture(path.cstring)
  if tex.isNil:
    return
  Texture(texture: tex)

proc load*(res: var Resources, T: type Texture, path: string) =
  res.textures[extractFilenameWithoutExt(path).TextureId] = T.load(path)

proc get*(res: var Resources, T: type Texture, id: string): T =
  res.textures[id.TextureId]

proc texPtr*(t: Texture): TexturePtr =
  t.texture

proc `delete=`*(tex: Texture) =
  destroyTexture(tex.texture)

proc hash*(a: TextureId): Hash {.borrow.}
proc `==`*(a, b: TextureId): bool {.borrow.}
