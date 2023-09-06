import patty, tables, os, raylib

import platform

type
  ResourceId* = string
  Resources* = object
    textures: Table[ResourceId, PlatformTexture]
    fonts: Table[ResourceId, PlatformFont]

proc extractFilenameWithoutExt(path: string): string =
  let subpath = extractFilename(path)
  result = subpath.substr(0, searchExtPos(subpath) - 1)

proc init*(T: type Resources): T =
  T(fonts: initTable[ResourceId, PlatformFont](),
    textures: initTable[ResourceId, PlatformTexture]())

proc loadImage*(res: var Resources, path: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.textures[path.extractFilenameWithoutExt()] = raylib.loadTexture(path)

proc loadImage*(res: var Resources, path, name: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.textures[name] = raylib.loadTexture(path)

proc loadFont*(res: var Resources, path: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.fonts[path.extractFilenameWithoutExt()] = raylib.loadFont(path)

proc loadFont*(res: var Resources, path, name: string) =
  assert path.existsFile(), ("failed to load image, file not found: " & path)
  res.fonts[name] = getFontDefault()

proc getImage*(res: var Resources, id: string): var PlatformTexture =
  result = res.textures[id]

proc getFont*(res: var Resources, id: string): var PlatformFont =
  result = res.fonts[id]
