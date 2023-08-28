import patty, tables, os

import platform

type
  ResourceKind = enum
    texture
    font

  Resource = object
    case kind: ResourceKind
      of texture:
        tex: PlatformTexture
      of font:
        fnt: PlatformFont

type
  ResourceId* = string
  Resources* = object
    store: Table[ResourceId, Resource]
    fonts: Table[ResourceId, PlatformFont]

proc Texture(tex: PlatformTexture): auto = Resource(kind: texture, tex: tex)
proc Font(fnt: sink PlatformFont): auto = Resource(kind: font, fnt: fnt)

proc extractFilenameWithoutExt(path: string): string =
  let subpath = extractFilename(path)
  result = subpath.substr(0, searchExtPos(subpath) - 1)

proc init*(T: type Resources): T =
  T(store: initTable[ResourceId, Resource]())

proc loadImage*(res: var Resources, path: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.store[path.extractFilenameWithoutExt()] = Texture(loadTexture(path))

proc loadImage*(res: var Resources, path, name: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.store[name] = Texture(loadTexture(path))

proc loadFont*(res: var Resources, path: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.store[path.extractFilenameWithoutExt()] = Font(loadFont(path))

proc loadFont*(res: var Resources, path, name: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.store[name] = Font(loadFont(path))

proc getImage*(res: var Resources, id: string): var PlatformTexture =
  result = res.store[id].tex

proc getFont*(res: var Resources, id: string): var PlatformFont =
  result = res.store[id].fnt
