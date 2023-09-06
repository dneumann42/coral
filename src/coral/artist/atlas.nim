import raylib
import os, sets, tables, algorithm, sugar, json, sequtils, strformat
import std/[paths, re]
import std/md5

type
  Config = object
    dir: string
    images: seq[string]
    hashes: Table[string, string]

  Rect = object
    id: string
    x, y, w, h: float
  Region = object
    x, y, w, h: float
  OutRect* = object
    id: string
    region: Region
  OutImage* = object
    id*: string
    path*: string
  Atlas* = object
    config: Config
    sprites: Table[string, OutRect]
    images: Table[string, OutImage]

proc equals(a, b: Table[string, string]): bool =
  result = true
  for k in a.keys:
    if a[k] != b[k]:
      return false

proc initRect(id: string, x, y, w, h: float): Rect =
  result.id = id
  result.x = x
  result.y = y
  result.w = w
  result.h = h

proc toOutRect(r: Rect): OutRect =
  result.id = r.id
  result.region = Region(x: r.x, y: r.y, w: r.w, h: r.h)

const DefaultExts = [".png", ".bmp"].toHashSet

func basename(path: string): string =
  let fn = path.extractFilename()
  result = path.substr(0, (path.len - fn.len) - 1)

proc load(T: type Config, path: Path): Config =
  result = readFile(path.string).parseJson().to(Config)
  result.dir = path.string.basename

proc allSpritesInFolder*(config: Config, dir: Path, exts = DefaultExts): seq[string] =
  for file in walkDirRec(dir.string):
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

proc generateAtlas(config: Config, path: Path): tuple[target: Image, rects: seq[Rect]] =
  result.target = genImageColor(512, 512, Color(r: 0, g: 0, b: 0, a: 0))
  result.rects = newSeq[Rect]()

  var images = newTable[string, Image]()

  for path in config.allSpritesInFolder(path):
    let id = getId(path)
    let img = loadImage(path)
    result.rects.add(initRect(id, 0.0, 0.0, img.width.float, img.height.float))
    images[id] = imageCopy(img)

  result.rects.sort (a, b: Rect) => cmp(b.h, a.h)

  var x, y, maxHeight = 0.0
  for r in result.rects.mitems:
    if x + r.w > result.target.width.float:
      y += maxHeight
      x = 0.0
      maxHeight = 0.0

    if y + r.h > result.target.height.float:
      break

    r.x = x
    r.y = y
    x += r.w
    maxHeight = max(r.h, maxHeight)

  for r in result.rects:
    let
      img = images[r.id]
      sr = Rectangle(x: 0, y: 0, width: img.width.float32,
          height: img.height.float32)
      dr = Rectangle(x: r.x, y: r.y, width: img.width.float32,
          height: img.height.float32)
    imageDraw(result.target, img, sr, dr, White)

proc createAtlasData*(config: Config, imagesDir: Path, rects: seq[
    Rect]): JsonNode =
  let images = collect:
    for p in config.allImagesInFolder(imagesDir):
      let id = getId(p)
      (id, OutImage(id: id, path: p))

  result = %* Atlas(
    sprites: rects.map(toOutRect).map(r => (r.id, r)).toTable,
    images: images.toTable
  )

proc updateHashes(config: var Config): bool =
  for path in config.allSpritesInFolder(config.dir.Path):
    let contents = readFile(path)
    let hash = contents.toMD5
    let id = path.extractFilename()

    if config.hashes[id] != $hash:
      result = true

    config.hashes[id] = $hash

proc start(imagesDir, outDir: Path, name = "atlas", format = "png",
    prettify = false) =

  var config = Config.load(imagesDir / "config.json".Path)

  if not fileExists(imagesDir.string / &"{name}.{format}") or config.updateHashes():
    let (atlas, rects) = config.generateAtlas(imagesDir)
    let atlasData = config.createAtlasData(imagesDir, rects)
    writeFile(outDir.string / &"{name}.json", atlasData.pretty)
    discard exportImage(atlas, (outDir.string / &"{name}.{format}").cstring)

  writeFile(imagesDir.string / "config.json", ( % config).pretty)

proc load*(T: type Atlas, atlasDirs: string) =
  start(atlasDirs.Path, atlasDirs.Path)

when isMainModule:
  import cligen
  dispatch start
