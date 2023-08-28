import vmath, chroma
from raylib import nil

const WIN_SIZE = vec2(1280, 720)

type
  PlatformRectangle* = tuple[x, y, w, h: float32]
  PlatformCanvas* = raylib.RenderTexture2D
  PlatformCamera* = raylib.Camera2D

  SomeIntRect = tuple[x, y, w, h: int]
  SomeFloatRect = tuple[x, y, w, h: float]
  SomeFloat32Rect = tuple[x, y, w, h: float32]
  SomeRectangle = SomeIntRect | SomeFloatRect | SomeFloat32Rect

converter toVector2*(v: Vec2): raylib.Vector2 {.inline.} = raylib.Vector2(
    x: v.x, y: v.y)
converter fromVector2*(v: raylib.Vector2): Vec2 {.inline.} = vec2(v.x, v.y)
converter toVector3*(v: Vec3): raylib.Vector3 {.inline.} = raylib.Vector3(
    x: v.x, y: v.y, z: v.z)
converter fromVector3*(v: raylib.Vector3): Vec3 {.inline.} = vec3(v.x, v.y, v.z)
converter toRectangle*(r: PlatformRectangle): raylib.Rectangle {.inline.} = raylib.Rectangle(
    x: r.x.float32, y: r.y.float32, width: r.w.float32, height: r.h.float32)

converter toPlatformRectangle*(r: SomeRectangle): PlatformRectangle =
  PlatformRectangle(
    x: r.x.float32,
    y: r.y.float32,
    w: r.w.float32,
    h: r.h.float32
  )

# converter toColor*(r)

proc screenWidth*(): float = raylib.getScreenWidth().float
proc screenHeight*(): float = raylib.getScreenHeight().float
proc screenSize*(): (float, float) =
  (screenWidth(), screenHeight())

proc init*(T: type PlatformCanvas, w, h: SomeNumber): T =
  raylib.loadRenderTexture(w.int32, h.int32)

proc init*(T: type PlatformCamera): T =
  raylib.Camera2D(target: vec2(), offset: screenSize() / 2.0).T

proc width*(c: PlatformCanvas): int = c.texture.width
proc height*(c: PlatformCanvas): int = c.texture.height
proc size*(c: PlatformCanvas): auto =
  vec2(c.width().float, c.height().float)

proc drawCanvas*(canvas: PlatformCanvas, src, dst: SomeRectangle) =
  raylib.drawTexture(canvas.texture, src, dst, vec2(), 0.0'f32, raylib.White)

func windowShouldClose*(): bool =
  result = raylib.windowShouldClose()

func centerWindow() =
  let pos = raylib.getMonitorPosition(raylib.getCurrentMonitor()) + vec2(
      WIN_SIZE.x / 2, WIN_SIZE.y / 2)

func initializeWindow*(title = "", width = WIN_SIZE.x,
    height = WIN_SIZE.y) =
  assert not raylib.isWindowReady(), "Window is already initialized"
  raylib.setConfigFlags raylib.flags(raylib.WindowResizable,
      raylib.WindowTopmost)
  raylib.initWindow(width.int32, height.int32, title)
  raylib.setTargetFPS(60)
  # setExitKey(cast[KeyboardKey](0))

template withDrawing*(body: untyped) =
  raylib.beginDrawing()
  raylib.clearBackground(raylib.Black)
  body
  raylib.endDrawing()

proc drawRectangle*(x, y, width, height: SomeNumber, origin: Vec2,
    rotation: SomeNumber, color: chroma.Color) =
  raylib.drawRectangle(
    raylib.Rectangle(x: x.float32, y: y.float32, width: width.float32,
        height: height.float32),
    raylib.Vector2(),
    0.0'f32,
    raylib.White
  )
