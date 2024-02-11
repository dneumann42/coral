import algorithm, sequtils, sugar, vmath, chroma, os, jsony, json, tables, print
import std/logging

import ../platform/application
import ../platform/renderer
import atlas

type
  Align* = enum
    left
    center
    right

  Justify* = enum
    top
    center
    bottom

  DrawRect* = object
    x*, y*, w*, h*: float 

  Layer* = ref object
    depth*: int
    camera*: bool
    target*: Canvas

  Artist* = object
    camera: Camera
    layers: seq[Layer]
    draws*: seq[DrawRect]

# proc `=copy`(dest: var Artist; source: Artist) {.error.}
# proc `=wasMoved`(x: var Artist) {.error.}

var containerSize = vec2()
var spriteAtlases = newSeq[SpriteAtlas]()

proc tup*(v: Vec2): (float32, float32) = (v.x, v.y)
proc tup*(v: Vec3): (float32, float32, float32) = (v.x, v.y, v.z)

proc `cameraPosition=`*(artist: var Artist; pos: Vec2) =
  artist.camera.position = pos

proc cameraPosition*(artist: Artist): Vec2 =
  artist.camera.position

proc `cameraZoom=`*(artist: var Artist; zoom: float) =
  artist.camera.zoom = zoom

proc cameraZoom*(artist: Artist): float =
  artist.camera.zoom

proc screenWidth*(): int =
  renderer.windowSize().x.int

proc screenHeight*(): int =
  renderer.windowSize().y.int

proc screenSize*(): tuple[w, h: int] =
  (screenWidth(), screenHeight())

proc layerWidth*(): int =
  containerSize.x.int

proc layerHeight*(): int =
  containerSize.y.int

proc layerCenter*(): Vec2 =
  containerSize / 2.0

proc init*(T: type Layer; w = screenWidth(); h = screenHeight(); depth = 0;
    camera = false): T =
  T(depth: depth,
    camera: camera,
    target: Canvas.init(screenWidth(), screenHeight()))

proc init*(T: type Artist): T =
  T(camera: Camera.init(),
    layers: @[])

proc loadAtlasConfig*(path: string): AtlasConfig =
  var cfg {.global.} : Option[AtlasConfig] 
  if cfg == none(AtlasConfig):
    cfg = AtlasConfig.load(path).some()
  result = cfg.get()

proc loadSpriteAtlas*(cfg: AtlasConfig, name: string): SpriteAtlas =
  var cache {.global.} : Table[string, SpriteAtlas]
  if not cache.hasKey(name):
    cache[name] = readFile(cfg.basePath / name & ".json").parseJson().to(SpriteAtlas)
  result = cache[name]

template withClip*(x, y, w, h: SomeNumber, blk: untyped) =
  application.withClip(x, y, w, h, blk)

proc intersects*(a, b: Vec2, radius = 10.0): bool =
  dist(a, b) < radius

proc intersects*(a, b: tuple[x, y, w, h: SomeNumber]): bool =
  a.x + a.w > b.x and a.x < b.x + b.w and a.y + a.h > b.y and a.y < b.y + b.h

proc intersects*(p: Vec2, a: tuple[x, y, w, h: float|float32]): bool =
  p.x > a.x and p.x < a.x + a.w and p.y > a.y and p.y < a.y + a.h

proc intersects*(p: Vec2, x, y, w, h: float|float32): bool =
  p.x > x and p.x < x + w and p.y > y and p.y < y + h

proc size*(layer: Layer): Vec2 =
  let (x, y) = layer.target.size()
  result.x = x.float
  result.y = y.float

proc drawLine*(startX, startY, endX, endY: SomeNumber, color = color(1.0, 1.0, 1.0, 1.0)) =
  application.line(startX, startY, endX, endY, color)

proc drawCircle*(x, y: SomeNumber; r = 32.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.circle(x, y, r, color)

proc drawCircle*(pos: Vec2; r = 32.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.circle(pos.x, pos.y, r, color)

proc drawRect*(x, y: SomeNumber; w = 64.0; h = 64.0; origin = vec2();
    rotation = 0.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.rect(x.float32, y.float32, w.float32, h.float32, origin, rotation, color)

proc drawRect*(pos, size: Vec2; origin = vec2();
    rotation = 0.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.rect(pos.x, pos.y, size.x, size.y, origin, rotation, color)

proc drawLinerect*(x, y: SomeNumber; w = 64.0; h = 64.0; origin = vec2();
    rotation = 0.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.linerect(x.float32, y.float32, w.float32, h.float32, origin, rotation, color)

proc drawLinerect*(pos, size: Vec2; origin = vec2();
    rotation = 0.0; color = color(1.0, 1.0, 1.0, 1.0)) =
  application.linerect(pos.x, pos.y, size.x, size.y, origin, rotation, color)

proc drawTexture*(
  textureId: string,
  src: Rectangle,
  dst: Rectangle,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)
) =
  application.texture(textureId, src, dst, origin, rotation, color)

proc drawTexture*(
  textureId: string,
  pos: Vec2,
  scale = 1.0,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)
) =
  application.texture(textureId, pos, scale, origin, rotation, color)

proc measureString*(text: string, fontId: string): Vec2 =
  application.measureString(text, fontId)

proc drawText*(
  tex: string,
  fontId: string, # TODO: font id should be distinct from string
  x, y: SomeNumber,
  color = color(1.0, 1.0, 1.0, 1.0)
) =
  application.text(tex, fontId, x, y, color)

proc getOrCreateLayer*(artist: var Artist; depth: int; camera = false): Layer =
  for layer in artist.layers:
    if layer.depth == depth:
      return layer
  result = Layer.init(depth = depth, camera = true)
  artist.layers.add(result)

template layer*(artist: var Artist; depth: int; body: untyped) =
  let layer = artist.getOrCreateLayer(depth)
  startCanvas(layer.target)
  containerSize = layer.size()
  body
  endCanvas()

template cameraLayer*(artist: var Artist; depth: int; body: untyped) =
  let layer = artist.getOrCreateLayer(depth)
  startCanvas(layer.target)
  containerSize = layer.size()
  setCamera(artist.camera)
  body
  unsetCamera()
  endCanvas()

proc clear*(artist: var Artist) =
  for layer in artist.layers.mitems:
    startCanvas(layer.target)
    clear()
    endCanvas()

proc paint*(artist: var Artist) =
  for layer in artist.layers.sorted((a, b) => a.depth.cmp(b.depth)):
    let (w, h) = layer.size().tup
    let src = (0.0, 0.0, w.float, h.float)
    let dst = (0.0, 0.0, w.float, h.float)
    texture(layer.target, src, dst)

  for shape in artist.draws:
    rect(shape.x, shape.y, shape.w, shape.h, color=color(1.0, 0.5, 0.0, 1.0))

  artist.draws.setLen(0)
