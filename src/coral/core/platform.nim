import vmath, chroma
from raylib import nil

const WIN_SIZE = vec2(1280, 720)

type
  Rectangle* = tuple[x, y, w, h: float32]
  Canvas* = raylib.RenderTexture2D
  Camera* = raylib.Camera2D
  KeyboardKey* = raylib.KeyboardKey
  GamepadButton* = raylib.GamepadButton
  MouseButton* = raylib.MouseButton

  PlatformFont* = raylib.Font
  PlatformTexture* = raylib.Texture2D

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
converter toRectangle*(r: Rectangle): raylib.Rectangle {.inline.} = raylib.Rectangle(
    x: r.x.float32, y: r.y.float32, width: r.w.float32, height: r.h.float32)

converter toPlatformRectangle*(r: SomeRectangle): Rectangle =
  (x: r.x.float32, y: r.y.float32, w: r.w.float32, h: r.h.float32)

converter toRayColor*(c: chroma.Color): raylib.Color =
  let v = c.asRgba
  result.r = v.r
  result.g = v.g
  result.b = v.b
  result.a = v.a

converter toChromaColor*(c: raylib.Color): chroma.Color =
  result.r = (c.r * 255).float32
  result.g = (c.g * 255).float32
  result.b = (c.b * 255).float32
  result.a = (c.a * 255).float32

proc screenWidth*(): float = raylib.getScreenWidth().float
proc screenHeight*(): float = raylib.getScreenHeight().float
proc screenSize*(): (float, float) =
  (screenWidth(), screenHeight())

proc init*(T: type Canvas, w, h: SomeNumber): T =
  raylib.loadRenderTexture(w.int32, h.int32)

proc init*(T: type Camera): T =
  raylib.Camera2D(target: vec2(), offset: screenSize() / 2.0).T

proc width*(c: Canvas): int = c.texture.width
proc height*(c: Canvas): int = c.texture.height
proc size*(c: Canvas): auto =
  vec2(c.width().float, c.height().float)

proc drawCanvas*(canvas: Canvas, src, dst: SomeRectangle) =
  raylib.drawTexture(canvas.texture, src, dst, vec2(), 0.0'f32, raylib.White)

template withCanvas*(canvas: Canvas, body: untyped) =
  raylib.beginTextureMode(canvas.texture)
  body
  raylib.endTextureMode()

func windowShouldClose*(): bool =
  result = raylib.windowShouldClose()

func centerWindow() =
  let pos = raylib.getMonitorPosition(raylib.getCurrentMonitor()) + vec2(
      WIN_SIZE.x / 2, WIN_SIZE.y / 2)

func initializeWindow*(title = "", width = WIN_SIZE.x,
    height = WIN_SIZE.y) =
  assert not raylib.isWindowReady(), "Window is already initialized"
  raylib.setConfigFlags raylib.flags(raylib.WindowResizable,
      raylib.WindowTopmost, raylib.Msaa4xHint)
  raylib.initWindow(width.int32, height.int32, title)
  raylib.setTargetFPS(60)
  raylib.setExitKey(cast[raylib.KeyboardKey](0))

proc isKeyPressed*(key: KeyboardKey): bool =
  raylib.isKeyPressed(key)

proc isKeyDown*(key: KeyboardKey): bool =
  raylib.isKeyDown(key)

proc isKeyReleased*(key: KeyboardKey): bool =
  raylib.isKeyReleased(key)

proc isKeyUp*(key: KeyboardKey): bool =
  raylib.isKeyUp(key)

proc loadTexture*(path: string): PlatformTexture =
  raylib.loadTexture(path)

proc loadFont*(path: string): PlatformFont {.inline.} =
  # raylib.loadFont(path, 64, 512)
  raylib.getFontDefault()

template withDrawing*(body: untyped) =
  raylib.beginDrawing()
  raylib.clearBackground(raylib.Black)
  body
  raylib.endDrawing()

proc measureText*(text: string, font: var PlatformFont, fontSize: float): Vec2 =
  let res = raylib.measureText(raylib.getFontDefault(), text.cstring,
      fontSize.float32, 1.0'f32)
  result.x = res.x
  result.y = res.y

proc drawRectangle*(x, y, w, h: SomeNumber, origin: Vec2,
    rotation: SomeNumber, color: Color) =
  raylib.drawRectangle(
    (x: x, y: y, w: w, h: h).toRectangle(),
    origin.toVector2(),
    rotation.float32,
    color.toRayColor()
  )

proc drawCircle*(x, y, r: SomeNumber, color: Color) =
  raylib.drawCircle(vec2(x, y), r.float32, color.toRayColor)

proc drawLine*(x1, y1, x2, y2: SomeNumber, thickness = 1.0, color: Color) =
  raylib.drawLine(
    vec2(x1, y1),
    vec2(x2, y2),
    thickness.float32,
    color
  )

proc drawText*(x, y: SomeNumber, text: string, font: PlatformFont,
    fontSize: float, rotation: float, color: Color) =
  raylib.drawText(
    font,
    text,
    raylib.Vector2(x: x.float32, y: y.float32),
    fontSize.float32,
    0.0,
    color
  )
