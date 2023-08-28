import algorithm, sequtils, sugar, vmath, chroma

import ../core/platform as pl

type
  Rect* = PlatformRectangle

  Canvas* = PlatformCanvas
  Camera* = PlatformCamera

  Layer* = ref object
    depth*: int
    camera*: bool
    target*: Canvas

  Artist* = object
    camera: Camera
    layers: seq[Layer]

proc tup*(v: Vec2): (float32, float32) = (v.x, v.y)
proc tup*(v: Vec3): (float32, float32, float32) = (v.x, v.y, v.z)

proc screenWidth*(): float = pl.screenWidth()
proc screenHeight*(): float = pl.screenHeight()

proc init*(T: type Layer, w = screenWidth(), h = screenHeight(), depth = 0,
    camera = false): T =
  T(depth: depth,
    camera: camera,
    target: Canvas.init(screenWidth(), screenHeight()))

proc init(T: type Artist): T =
  T(camera: Camera.init(),
    layers: @[])

template withDrawing*(body: untyped) =
  pl.withDrawing(body)

proc size*(layer: Layer): Vec2 =
  layer.target.size()

proc line*(x1, y1, x2, y2: SomeNumber, thickness = 1.0, color = color(1.0, 1.0,
    1.0, 1.0)) =
  drawLine(x1, y1, x2, y2, thickness, color)

proc circle*(x, y: SomeNumber, r = 32.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  drawCircle(x, y, r, color)

proc rect*(x, y: SomeNumber, w = 64.0, h = 64.0, origin = vec2(),
    rotation = 0.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  drawRectangle(x, y, w, h, origin, rotation, color)

template layer*(artist: Artist, depth: int, body: untyped) =
  if artist.layers.findIt(it.depth == depth) >= 0:
    artist.layers.add((depth, Layer.init(depth = depth)))

proc paint*(artist: var Artist) =
  for layer in artist.layers.sorted((a, b) => a.depth.cmp(b.depth)):
    let (w, h) = layer.size().tup
    let src = (0.0'f32, 0.0'f32, w, -h)
    let dst = (screenWidth().float32 / 2.0'f32 - w / 2.0'f32, screenHeight(
      ).float32 / 2.0'f32 + h / 2.0'f32, w, -h)
    layer.target.drawCanvas(src, dst)
