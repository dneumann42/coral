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
    layers: seq[(int, Layer)]

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

proc line*() = discard
proc circle*() = discard

proc rect*(x, y: SomeNumber, w = 32.0, h = 32.0, origin = vec2(),
    rotation = 0.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  drawRectangle(x, y, w, h, origin, rotation, color)

proc paint*(artist: var Artist) =
  for (_, layer) in artist.layers.sorted((a, b) => a[0].cmp(b[0])):
    let size = layer.size()
    let (w, h) = (size.x, size.y)
    let src = (0.0'f32, 0.0'f32, w, -h)
    let dst = (screenWidth().float32 / 2.0'f32 - w / 2.0'f32, screenHeight(
      ).float32 / 2.0'f32 + h / 2.0'f32, w, -h)
    layer.target.drawCanvas(src, dst)
