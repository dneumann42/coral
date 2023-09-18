import algorithm, sequtils, sugar, vmath, chroma

import ../platform/application

from ../platform/renderer import Canvas, Camera, size

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

proc tup*(v: Vec2): (float32, float32) = (v.x, v.y)
proc tup*(v: Vec3): (float32, float32, float32) = (v.x, v.y, v.z)

proc screenWidth*(): float =
  let (w, _) = windowSize()
  w.float

proc screenHeight*(): float =
  let (h, _) = windowSize()
  h.float

proc init*(T: type Layer, w = screenWidth(), h = screenHeight(), depth = 0,
    camera = false): T =
  T(depth: depth,
    camera: camera,
    target: Canvas.init(screenWidth(), screenHeight()))

proc init*(T: type Artist): T =
  T(camera: Camera.init(),
    layers: @[])

proc size*(layer: Layer): Vec2 =
  let (x, y) = layer.target.size()
  result.x = x.float
  result.y = y.float

proc circle*(x, y: SomeNumber, r = 32.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  application.circle(x, y, r, color)

proc rect*(x, y: SomeNumber, w = 64.0, h = 64.0, origin = vec2(),
    rotation = 0.0, color = color(1.0, 1.0, 1.0, 1.0)) =
  application.rect(x.float32, y.float32, w.float32, h.float32, origin, rotation, color)

# proc text*(font: var PlatformFont, x, y: SomeNumber, text = "Hello, World",
#     fontSize = 32.0, rotation = 0.0, color = color(1.0, 1.0, 1.0,
#     1.0), align: Align = left) =
#   let size = measureText(text, font, fontSize)
#   if align == left:
#     drawText(x, y, text, font, fontSize, rotation, color)
#   if align == center:
#     drawText(x - size.x / 2.0, y, text, font, fontSize, rotation, color)

template layer*(artist: Artist, depth: int, body: untyped) =
  if artist.layers.findIt(it.depth == depth) >= 0:
    artist.layers.add((depth, Layer.init(depth = depth)))
  startCanvas(artist.layers[depth].target)
  body
  endCanvas()

template cameraLayer*(artist: Artist, depth: int, body: untyped) =
  if artist.layers.findIt(it.depth == depth) >= 0:
    artist.layers.add((depth, Layer.init(depth = depth, camera = true)))
  startCanvas(artist.layers[depth].target)
  artist.camera.withCamera():
    clearBackground()
    body
  endCanvas()

proc paint*(artist: var Artist) =
  for layer in artist.layers.sorted((a, b) => a.depth.cmp(b.depth)):
    let (w, h) = layer.size().tup
    let src = (0.0'f32, 0.0'f32, w, -h)
    let dst = (screenWidth().float32 / 2.0'f32 - w / 2.0'f32, screenHeight(
      ).float32 / 2.0'f32 + h / 2.0'f32, w, -h)
    # layer.target.drawCanvas(src, dst)
