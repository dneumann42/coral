import os, tables, algorithm, sugar, json, sequtils, strformat
import options, sdl2, sdl2/image, streams, yaml
import std/logging
import ../platform/resources
import ../platform/renderer
import ../platform/application
import ../platform/state

export tables, yaml

const
  R_MASK = 0xff000000.uint32
  G_MASK = 0x00ff0000.uint32
  B_MASK = 0x0000ff00.uint32
  A_MASK = 0x000000ff.uint32

type
  AtlasConfig* = object
    basePath*: string
    fonts: Table[string, string]
    images: Table[string, string]
    atlases: Table[string, string]

  ImageSprite* = object
    x*, y*, w*, h*: int

  SpriteAtlas* = object
    imageId: string
    sprites*: Table[string, ImageSprite]

  Atlas* = object
    spriteAtlases*: seq[SpriteAtlas]

proc getId(path: string): string =
  let fn = extractFilename(path)
  result = fn.substr(0, searchExtPos(fn)-1)

proc load*(T: type AtlasConfig, path: string): T =
  if not fileExists(path):
    raise IOError.newException("File does not exist: " & path)
  var fs = newFileStream(path)
  fs.load(result) 
  fs.close()
  info("Loaded Atlas Config: " & path)

proc init*(T: type ImageSprite, x, y, w, h: int): T =
  T(x: x, y: y, w: w, h: h)

proc write*(config: AtlasConfig, path: string) =
  var fs = newFileStream(path, fmWrite)
  Dumper().dump(config, fs)
  fs.close()

proc eachImage*(config: AtlasConfig, fn: proc(path, key: string): void) =
  for k, v in config.images.pairs:
    fn(v, k) 

proc generateSpriteAtlases*(config: AtlasConfig): seq[SpriteAtlas] =
  result = @[]
  for image, dir in config.atlases.pairs:
    var atlas = SpriteAtlas(imageId: image, sprites: initTable[string, ImageSprite]())
    defer: result.add(atlas)

    let path =  config.basePath / dir
    var textures = initTable[string, TexturePtr]()

    const W = 1024
    const H = 1024
    var canvas = Canvas.init(W, H)

    # cleanup
    defer: canvas.destroyTexture()
    defer:
      for tex in textures.values:
        tex.destroyTexture()

    # Load all textures in directory
    for path in walkFiles(path / "*.png"):
      let img: TexturePtr = getRenderer().loadTexture(path)
      let (w, h) = img.size()
      var spriteId = &"{image}-{path.getId()}"
      textures[spriteId] = img
      atlas.sprites[spriteId] = ImageSprite.init(0, 0, w, h)

    var sprites = atlas.sprites.pairs.toSeq()
    sprites.sort (a, b: (string, ImageSprite)) => cmp(b[1].h, a[1].h)

    var x, y, maxHeight = 0
    for (id, spr) in sprites.mitems:
      if x + spr.w > W:
        y += maxHeight
        x = 0
        maxHeight = 0
      if y + spr.h > H:
        break
      spr.x = x
      spr.y = y
      x += spr.w
      maxHeight = max(spr.h, maxHeight)
      atlas.sprites[id] = spr

    # render spritesheet to canvas
    startCanvas(canvas)
    for (id, sprite) in sprites:
      let
        tex = textures[id]
        (tw, th) = tex.size()
      texture(
        tex,
        (0.0, 0.0, tw.toFloat, th.toFloat),
        (sprite.x.toFloat, sprite.y.toFloat, tw.toFloat, th.toFloat))
    var surface = createRGBSurface(0, W, H, 32, R_MASK, G_MASK, B_MASK, A_MASK)
    discard getRenderer().readPixels(nil, surface.format.format.cint,
        surface.pixels, surface.pitch)
    discard savePNG(surface, config.basePath / (image & "-atlas.png"))
    endCanvas()

    writeFile(config.basePath / (image & "-atlas.json"), 
      ( %* atlas).pretty)

when isMainModule:
  var conf = AtlasConfig.load("res/config.yaml")
  conf.write("test.yaml")
  discard conf.generateSpriteAtlases()
