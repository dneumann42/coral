import raylib, vmath

const WIN_SIZE = vec2(1280, 720)

converter toVector2*(v: Vec2): raylib.Vector2 {.inline.} =
  Vector2(x: v.x, y: v.y)

converter fromVector2*(v: raylib.Vector2): Vec2 {.inline.} =
  result = vec2(v.x, v.y)

converter toVector3*(v: Vec3): raylib.Vector3 {.inline.} =
  Vector3(x: v.x, y: v.y, z: v.z)

converter fromVector3*(v: raylib.Vector3): Vec3 {.inline.} =
  result = vec3(v.x, v.y, v.z)

func windowShouldClose*(): bool =
  result = raylib.windowShouldClose()

func centerWindow() =
  let pos = getCurrentMonitor().getMonitorPosition() + vec2(WIN_SIZE.x / 2,
      WIN_SIZE.y / 2)

func initializeWindow*(title = "", width = WIN_SIZE.x,
    height = WIN_SIZE.y) =
  assert not isWindowReady(), "Window is already initialized"
  setConfigFlags flags(WindowResizable, WindowTopmost)
  initWindow(width.int32, height.int32, title)
  setTargetFPS(60)
  # setExitKey(cast[KeyboardKey](0))

template withDrawing*(body: untyped) =
  beginDrawing()
  clearBackground(Black)
  body
  endDrawing()
