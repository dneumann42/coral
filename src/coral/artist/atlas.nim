import os, sets, tables, algorithm, sugar, json, sequtils, strformat, options,
    strutils, sets, sdl2, sdl2/image, print, jsony
import std/[paths, re]
import std/md5
import ../platform/resources
import ../platform/renderer
import ../platform/application
import ../platform/state

const
  R_MASK = 0xff000000.uint32
  G_MASK = 0x00ff0000.uint32
  B_MASK = 0x0000ff00.uint32
  A_MASK = 0x000000ff.uint32

type
  Image = object
  Config = object
    dir: string
    images*: seq[string]
    atlases*: seq[string]
    hashes: Table[string, string]

  Sprite = object
    id*: string
    x*, y*, w*, h*: float

  SpriteAtlas* = object
    imageId: string
    sprites: seq[Sprite]

  Region = object
    x, y, w, h: float
  OutRect* = object
    id: string
    region: Region

  OutImage* = object
    id*: string
    path*: string

  ImageGroup* = object
    id*: string
    images*: seq[OutImage]

  Atlas* = object
    config*: Config
    sprites*: Table[string, Sprite]
    imageGroups*: Table[string, ImageGroup]
    spriteAtlases: seq[SpriteAtlas]

proc equals(a, b: Table[string, string]): bool =
  result = true
  for k in a.keys:
    if a[k] != b[k]:
      return false

proc init(T: type Sprite, id: string, x, y, w, h: float): T =
  T(id: id, x: x, y: y, w: w, h: h)

proc init*(T: type Atlas): T =
  T()

proc toOutRect(r: Sprite): OutRect =
  result.id = r.id
  result.region = Region(x: r.x, y: r.y, w: r.w, h: r.h)

const DefaultExts = [".png", ".bmp"].toHashSet

func basename(path: string): string =
  let fn = path.extractFilename()
  result = path.substr(0, (path.len - fn.len) - 1)

proc load*(T: type Config, path: string): Config =
  result = readFile(path).parseJson().to(Config)
  result.dir = path.basename

# @depricated
proc allSpritesInFolder*(config: Config, exts = DefaultExts): seq[string] =
  for file in walkDirRec(config.dir.string):
    if config.images.contains(file.basename.lastPathPart):
      continue
    if config.atlases.contains(file.basename.lastPathPart):
      continue
    if file.substr(searchExtPos(file), len(file)) in exts:
      result.add(file)

proc allImagesInFolder*(config: Config, dir: Path, exts = DefaultExts): seq[string] =
  for file in walkDirRec(dir.string):
    if config.images.contains(file.basename.lastPathPart):
      if file.substr(searchExtPos(file), len(file)) in exts:
        result.add(file)

proc getId(path: string): string =
  let fn = extractFilename(path)
  result = fn.substr(0, searchExtPos(fn)-1)

proc generateSpriteAtlas*(path: string): SpriteAtlas =
  var imageId = path.extractFilename()
  result = SpriteAtlas(sprites: @[], imageId: imageId)

  var textures = initTable[string, TexturePtr]()

  const W = 512
  const H = 512

  var canvas = Canvas.init(W, H)

  defer:
    canvas.destroyTexture()

  defer:
    for tex in textures.values:
      destroyTexture(tex)

  for file in walkDirRec(path):
    if file.substr(searchExtPos(file), len(file)) notin DefaultExts:
      continue
    let img = getRenderer().loadTexture(file)
    let (w, h) = img.size()
    var sprId = &"{imageId}-{file.getId()}"
    textures[sprId] = img
    result.sprites.add(Sprite.init(sprId, 0.0, 0.0, w.float, h.float))

  ## Sort and place sprites on spritesheet
  result.sprites.sort (a, b: Sprite) => cmp(b.h, a.h)
  var x, y, maxHeight = 0.0
  for spr in result.sprites.mitems:
    if x + spr.w > W:
      y += maxHeight
      x = 0.0
      maxHeight = 0.0
    if y + spr.h > H:
      break
    spr.x = x
    spr.y = y
    x += spr.w
    maxHeight = max(spr.h, maxHeight)

  ## Render spritesheet to canvas
  startCanvas(canvas)
  for spr in result.sprites:
    let
      tex = textures[spr.id]
      (tw, th) = tex.size()
    texture(
      tex,
      (0.0, 0.0, tw.float, th.float),
      (spr.x, spr.y, tw.float, th.float)
    )

  var surface = createRGBSurface(0, W, H, 32, R_MASK, G_MASK, B_MASK, A_MASK)
  discard getRenderer().readPixels(nil, surface.format.format.cint,
      surface.pixels, surface.pitch)
  discard savePNG(surface, "res" / "textures" / (imageId & "_atlas.png"))
  endCanvas()

proc createAtlasData*(config: Config): Atlas =
  result = Atlas(
    imageGroups: initTable[string, ImageGroup]()
  )

  for atlas in config.atlases:
    result.spriteAtlases.add(generateSpriteAtlas(config.dir / atlas))

  var groups: seq[tuple[id: string, path: string]] = @[]

  for item in walkDir(config.dir):
    if item.kind != pcDir:
      continue
    for group in config.images:
      if item.path.endsWith(group):
        groups.add((group, item.path))
        break

  for (id, path) in groups:
    var imgGroup = ImageGroup(id: id, images: @[])
    for item in walkDir(path):
      if not item.path.endsWith("png"):
        continue
      let imgId = item.path.extractFilenameWithoutExt()
      imgGroup.images.add(OutImage(id: &"{id}-{imgId}", path: item.path))
    result.imageGroups[id] = imgGroup

iterator sprites*(atlas: Atlas): tuple[id: string, region: Rectangle] =
  for spriteId in atlas.sprites.keys:
    let spr = atlas.sprites[spriteId]
    yield (spriteId, (spr.x, spr.y, spr.w, spr.h))

proc getSpriteImage*(atlas: Atlas, spriteId: string): string =
  ## Returns image id given sprite id
  for spriteAtlas in atlas.spriteAtlases:
    for sprite in spriteAtlas.sprites:
      if sprite.id == spriteId:
        return spriteAtlas.imageId

proc getSpriteRegion*(atlas: Atlas, spriteId: string): Rectangle =
  let imageId = atlas.getSpriteImage(spriteId)
  for spriteAtlas in atlas.spriteAtlases:
    if spriteAtlas.imageId == imageId:
      for spr in spriteAtlas.sprites:
        if spr.id == spriteId:
          return (spr.x, spr.y, spr.w, spr.h)

proc updateHashes*(config: var Config): bool =
  for path in config.allSpritesInFolder():
    let contents = readFile(path)
    let hash = contents.toMD5
    let id = path.extractFilename()

    if config.hashes[id] != $hash:
      result = true

    config.hashes[id] = $hash

proc loadConfig*(atlasDir: string): Config =
  Config.load(atlasDir / "config.json")

proc load*(T: type Atlas, atlasDirs: string): T =
  readFile(atlasDirs / "atlas.json").parseJson().to(T)

proc loadAtlas*(atlas: var Atlas, atlasPath: string) =
  let loaded = "res/textures".loadConfig().createAtlasData()
  atlas.config = loaded.config
  atlas.imageGroups = loaded.imageGroups
  atlas.spriteAtlases = loaded.spriteAtlases
  atlas.sprites = loaded.sprites
  writeFile(atlasPath / "atlas.json", atlas.toJson().parseJson().pretty)

proc getImageGroup*(atlas: Atlas, id: string): lent ImageGroup =
  if not atlas.imageGroups.hasKey(id):
    raise CatchableError.newException("Image Group not found: " & id)
  result = atlas.imageGroups[id]

proc getImageGroupImages*(atlas: Atlas, id: string): lent seq[OutImage] =
  if not atlas.imageGroups.hasKey(id):
    raise CatchableError.newException("Image Group not found: " & id)
  result = atlas.getImageGroup(id).images

proc spriteRegion*(atlas: Atlas, spriteId: string): Rectangle =
  result = atlas.getSpriteRegion(spriteId)

when isMainModule:
  import cligen
  # dispatch start
