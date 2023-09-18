import algorithm, sequtils, sugar, vmath, chroma, os, jsony

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

  Layer* = ref object
    depth*: int
    camera*: bool
    target*: Canvas

  Artist* = object
    camera: Camera
    layers: seq[Layer]
    atlas: Atlas

var containerSize = vec2()

proc tup*(v: Vec2): (float32, float32) = (v.x, v.y)
proc tup*(v: Vec3): (float32, float32, float32) = (v.x, v.y, v.z)

proc screenWidth*(): int =
  let (w, _) = windowSize()
  w

proc screenHeight*(): int =
  let (_, h) = windowSize()
  h

proc layerWidth*(): int =
  containerSize.x.int

proc layerHeight*(): int =
  containerSize.y.int

proc layerCenter*(): Vec2 =
  containerSize / 2.0

proc init*(T: type Layer, w = screenWidth(), h = screenHeight(), depth = 0,
    camera = false): T =
  T(depth: depth,
    camera: camera,
    target: Canvas.init(screenWidth(), screenHeight()))

proc init*(T: type Artist): T =
  T(camera: Camera.init(),
    layers: @[])

proc atlas*(artist: Artist): Atlas =
  artist.atlas

proc loadAtlas*(artist: var Artist, atlasPath: string) =
  artist.atlas = "res/textures".loadConfig().createAtlasData(@[])
  writeFile(atlasPath / "atlas.json",  artist.atlas.toJson())

proc size*(layer: Layer): Vec2 =
  let (x, y) = layer.target.size()
  result.x = x.float
  result.y = y.float

proc circle*(x, y: SomeNumber, r = 32.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  application.circle(x, y, r, color)

proc rect*(x, y: SomeNumber, w = 64.0, h = 64.0, origin = vec2(),
    rotation = 0.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  application.rect(x.float32, y.float32, w.float32, h.float32, origin, rotation, color)

proc getOrCreateLayer*(artist: var Artist, depth: int, camera = false): Layer =
  for layer in artist.layers:
    if layer.depth == depth:
      return layer
  result = Layer.init(depth = depth, camera = true)
  artist.layers.add(result)

template layer*(artist: var Artist, depth: int, body: untyped) =
  let layer = artist.getOrCreateLayer(depth)
  startCanvas(layer.target)
  containerSize = layer.size()
  body
  endCanvas()

template cameraLayer*(artist: var Artist, depth: int, body: untyped) =
  let layer = artist.getOrCreateLayer(depth)
  startCanvas(layer.target, true)
  containerSize = layer.size()
  artist.camera.withCamera() do:
    body
  endCanvas()

proc paint*(artist: var Artist) =
  for layer in artist.layers.sorted((a, b) => a.depth.cmp(b.depth)):
    let (w, h) = layer.size().tup
    let src = (0.0, 0.0, w.float, h.float)
    let dst = (0.0, 0.0, w.float, h.float)
    texture(layer.target, src, dst)
