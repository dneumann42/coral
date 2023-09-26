import os, sets, tables, algorithm, sugar, json, sequtils, strformat, options,
    strutils, sets, sdl2, sdl2/image
import std/[paths, re]
import std/md5
import ../platform/resources
import ../platform/renderer
import ../platform/application
import ../platform/state

type
  Image = object
  Config = object
    dir: string
    images*: seq[string]
    hashes: Table[string, string]

  Sprite = object
    id*: string
    x*, y*, w*, h*: float

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

proc equals(a, b: Table[string, string]): bool =
  result = true
  for k in a.keys:
    if a[k] != b[k]:
      return false

proc init(T: type Sprite, id: string, x, y, w, h: float): T =
  T(id: id, x: x, y: y, w: w, h: h)

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

proc allSpritesInFolder*(config: Config, exts = DefaultExts): seq[string] =
  for file in walkDirRec(config.dir.string):
    if config.images.contains(file.basename.lastPathPart):
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

proc generateSpritesheet*(config: Config): seq[Sprite] =
  result = @[]

  var canvas = Canvas.init(512, 512)
  defer: canvas.destroyTexture()

  startCanvas(canvas)

  var textures = initTable[string, TexturePtr]()
  for imagePath in config.allSpritesInFolder():
    if imagePath.endsWith("atlas.png") or imagePath.endsWith("out.png"):
      continue
    let img = getRenderer().loadTexture(imagePath)
    var w, h: cint
    queryTexture(img, nil, nil, w.addr, h.addr)
    textures[imagePath.getId()] = getRenderer().loadTexture(imagePath)
    result.add(Sprite.init(imagePath.getId(), 0.0, 0.0, w.float, h.float))

  result.sort (a, b: Sprite) => cmp(b.h, a.h)

  var x, y, maxHeight = 0.0
  for r in result.mitems:
    if x + r.w > 512:
      y += maxHeight
      x = 0.0
      maxHeight = 0.0

    if y + r.h > 512:
      break

    r.x = x
    r.y = y
    x += r.w
    maxHeight = max(r.h, maxHeight)

  for r in result:
    let tex = textures[r.id]
    var tw, th: cint

    queryTexture(tex, nil, nil, tw.addr, th.addr)

    let
      sr: Rectangle = (0.0, 0.0, tw.float, th.float)
      dr: Rectangle = (r.x, r.y, tw.float, th.float)

    texture(tex, sr, dr)

  var w, h: cint
  queryTexture(canvas, nil, nil, w.addr, h.addr)

  var
    rmask = 0xff000000.uint32
    gmask = 0x00ff0000.uint32
    bmask = 0x0000ff00.uint32
    amask = 0x000000ff.uint32

  var surface = createRGBSurface(0, w, h, 32, rmask, gmask, bmask, amask)
  var rec = (0.0, 0.0, 0.0, 0.0).toSDLRect

  discard getRenderer().readPixels(nil, surface.format.format.cint,
      surface.pixels, surface.pitch)

  discard savePNG(surface, "res" / "textures" / "atlas.png")

  for tex in textures.values:
    destroyTexture(tex)

  endCanvas()

proc createAtlasData*(config: Config): Atlas =
  var sprites = config.generateSpritesheet()

  var groups: seq[tuple[id: string, path: string]] = @[]

  for item in walkDir(config.dir):
    if item.kind != pcDir:
      continue
    for group in config.images:
      if item.path.endsWith(group):
        groups.add((group, item.path))
        break

  result = Atlas()

  for sprite in sprites:
    result.sprites[sprite.id] = sprite

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

proc getSpriteRegion*(atlas: Atlas, id: string): Rectangle =
  let spr = atlas.sprites[id]
  (spr.x, spr.y, spr.w, spr.h)

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

proc start(imagesDir, outDir: string, name = "atlas", format = "png",
    prettify = false) =
  var config = imagesDir.loadConfig()
  var rects = config.generateSpritesheet()

  writeFile(imagesDir.string / "config.json", ( % config).pretty)

proc load*(T: type Atlas, atlasDirs: string): T =
  readFile(atlasDirs / "atlas.json").parseJson().to(T)

when isMainModule:
  import cligen
  # dispatch start
