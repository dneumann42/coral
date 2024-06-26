import sdl2, tables, chroma, opengl, vmath, std/[logging, paths]
import state, resources, renderer, keys, strformat
import sdl2/ttf
import sdl2/image

template sdlFailIf(condition: typed, reason: string) =
  if condition:
    raise newException(OSError, reason)

var consoleLog = newConsoleLogger()
var fileLog = newFileLogger("errors.log", levelThreshold = lvlError)

addHandler(consoleLog)
addHandler(fileLog)

var capFps = true
var targetFPS: uint32 = 60
var previousTicks: uint64 = 0
var seconds = 0.0
var secondsAccum = 0.0

type
  Clock = object
    dt: float
    timer: float
    ticks: uint64

  MouseButton* = enum
    mouseLeft = 1
    mouseMiddle
    mouseRight

var
  ren: Renderer
  res: Resources
  context: GlContextPtr

  inputs: Table[KeyboardKey, bool]
  lastInputs: Table[KeyboardKey, bool]
  mouseInputs: Table[MouseButton, bool]
  lastMouseInputs: Table[MouseButton, bool]

  prev: uint64
  clock = Clock()

proc fps*(): float =
  if clock.dt == 0.0:
    return 0.0
  1.0 / clock.dt

proc getGLContext*(): GLContextPtr =
  context

proc clockTimer*(): float =
  clock.timer

proc toKeyboardKey(code: Scancode): KeyboardKey =
  cast[KeyboardKey](code)

proc initializeWindow*(title: string) =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialiation failed"

  sdlFailIf(ttfInit() == False32, "SDL2 TTF failed to initialize")
  sdlFailIf(image.init() == 0, "SDL2 IMG failed to initialize")

  setWindow(
    createWindow(
      title = title,
      x = SDL_WINDOWPOS_CENTERED,
      y = SDL_WINDOWPOS_CENTERED,
      w = 1280,
      h = 720,
      flags = SDL_WINDOW_SHOWN,
    )
  )

  sdlFailIf(getWindow().isNil):
    "Window could not be created"

  context = getWindow().glCreateContext()
  discard glSetSwapInterval(-1)
  loadExtensions()

  glClearColor(0.0, 0.0, 0.0, 1.0) # Set background color to black and opaque
  glClearDepth(1.0) # Set background depth to farthest
  glEnable(GL_DEPTH_TEST) # Enable depth testing for z-culling
  glDepthFunc(GL_LEQUAL) # Set the type of depth-test
  glShadeModel(GL_SMOOTH) # Enable smooth shading
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST) # Nice perspective corrections

  discard setHint("SDL_HINT_RENDER_SCALE_QUALITY", "2")
  discard setHint("SDL_HINT_RENDER_LINE_METHOD", "3")
  discard glSetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4)

  setRenderer(
    createRenderer(
      window = getWindow(),
      index = 0,
      flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture,
    )
  )

  sdlFailIf(getRenderer().isNil):
    &"Renderer could not be created: {getError()}"

  clock.ticks = getPerformanceCounter()
  ren = Renderer.init()
  res = Resources.init()

proc windowSize*(): Vec2 =
  renderer.windowSize()

proc getSaveDirectoryPath*(organization, app: string): Path =
  var path = $getPrefPath(organization.cstring, app.cstring)
  path.Path

proc isDown*(key: KeyboardKey): bool =
  if inputs.hasKey(key):
    inputs[key]
  else:
    false

proc isUp*(key: KeyboardKey): bool =
  not key.isDown()

proc isPressed*(key: KeyboardKey): bool =
  if inputs.hasKey(key):
    inputs[key] and (not lastInputs.hasKey(key) or not lastInputs[key])
  else:
    false

proc isReleased*(key: KeyboardKey): bool =
  if inputs.hasKey(key) and lastInputs.hasKey(key):
    not inputs[key] and lastInputs[key]
  else:
    false

proc isDown*(mouse: MouseButton): bool =
  if mouseInputs.hasKey(mouse):
    mouseInputs[mouse]
  else:
    false

proc isUp*(mouse: MouseButton): bool =
  not mouse.isDown()

proc clear*(mouse: MouseButton) =
  mouseInputs.del(mouse)

proc isPressed*(mouse: MouseButton): bool =
  if mouseInputs.hasKey(mouse):
    mouseInputs[mouse] and
      (not lastMouseInputs.hasKey(mouse) or not lastMouseInputs[mouse])
  else:
    false

proc isReleased*(mouse: MouseButton): bool =
  if mouseInputs.hasKey(mouse) and lastMouseInputs.hasKey(mouse):
    not mouseInputs[mouse] and lastMouseInputs[mouse]
  else:
    false

proc update*(mouse: MouseButton) =
  lastMouseInputs[mouse] = false
  mouseInputs[mouse] = false

proc mousePosition*(): Vec2 =
  var ix, iy: cint
  sdl2.getMouseState(ix.addr, iy.addr)
  result = vec2(ix.float, iy.float)

proc intersects*(a, b: Vec2, radius = 10.0): bool =
  dist(a, b) < radius

proc intersects*(a, b: tuple[x, y, w, h: SomeNumber]): bool =
  a.x + a.w > b.x and a.x < b.x + b.w and a.y + a.h > b.y and a.y < b.y + b.h

proc intersects*(p: Vec2, a: tuple[x, y, w, h: float | float32]): bool =
  p.x > a.x and p.x < a.x + a.w and p.y > a.y and p.y < a.y + a.h

proc intersects*(p: Vec2, x, y, w, h: float | float32): bool =
  p.x > x and p.x < x + w and p.y > y and p.y < y + h

proc closeWindow*() =
  sdl2.quit()
  if not getWindow().isNil:
    getWindow().destroy()
  if not getRenderer().isNil:
    getRenderer().destroy()

proc deltaTime*(): float =
  clock.dt

proc updateWindow*(): bool =
  result = true

  var event = defaultEvent

  for key in inputs.keys:
    lastInputs[key] = inputs[key]
  for mouse in mouseInputs.keys:
    lastMouseInputs[mouse] = mouseInputs[mouse]

  var TPS = getPerformanceFrequency()

  if prev == 0:
    prev = getPerformanceCounter()
  else:
    clock.ticks = getPerformanceCounter()
    clock.dt = (clock.ticks - prev).float64 / TPS.float64
    clock.timer += clock.dt
    prev = clock.ticks

  secondsAccum += clock.dt

  while pollEvent(event):
    case event.kind
    of QuitEvent:
      return false
    of KeyDown:
      inputs[event.key.keysym.scancode.toKeyboardKey] = true
    of KeyUp:
      inputs[event.key.keysym.scancode.toKeyboardKey] = false
    of MouseButtonDown:
      mouseInputs[event.button.button.MouseButton] = true
    of MouseButtonUp:
      mouseInputs[event.button.button.MouseButton] = false
    else:
      discard

proc shouldUpdate*(): bool =
  result = false
  if secondsAccum >= 1.0 / targetFPS.float:
    secondsAccum -= 1.0 / targetFPS.float
    return true

proc beginDrawing() =
  ren.beginDrawing()

proc endDrawing() =
  ren.endDrawing()

proc beginClip*(x, y, w, h: int) =
  ren.beginClip(x, y, w, h)

proc endClip*() =
  ren.endClip()

template withClip*(x, y, w, h: SomeNumber, blk: untyped) =
  beginClip(x.int, y.int, w.int, h.int)
  blk
  endClip()

proc startCanvas*(canvas: Canvas) =
  getRenderer().setRenderTarget(canvas)

proc clearCanvas*(canvas: Canvas) =
  ren.pushColor(color(0.0, 0.0, 0.0, 0.0)):
    getRenderer().clear()

proc endCanvas*() =
  getRenderer().setRenderTarget(nil)

proc loadImage*(path, id: string) =
  res.load(Texture, path, id)

proc loadFont*(path, id: string, size: int) =
  res.load(Font, path, id, size)

proc loadImage*(path: string) =
  res.load(Texture, path, path.extractFilenameWithoutExt())

proc loadFont*(path: string, size: int) =
  res.load(Font, path, path.extractFilenameWithoutExt(), size)

# TODO: make fontId distinct so accedental assignment is prevented
proc measureString*(text: string, fontId: string): Vec2 =
  result = res.get(Font, fontId).measureString(text)

proc textureSize*(texId: string): Vec2 =
  var (w, h) = size(res.get(Texture, texId))
  result = vec2(w, h)

proc clear*(color = color(0.0, 0.0, 0.0, 0.0)) =
  ren.clear(color = color)

proc text*(
    tex: string,
    fontId: string,
    x, y: SomeNumber,
    color = color(1.0, 1.0, 1.0, 1.0),
    breakX = -1,
) =
  ren.text(tex, res.get(Font, fontId), fontId, x, y, color, breakX = breakX)

proc line*(startX, startY, endX, endY: SomeNumber, color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.line(startX, startY, endX, endY, color)

proc rect*(
    x, y, w, h: SomeNumber,
    origin = vec2(),
    rotation = 0.0,
    color = color(1.0, 1.0, 1.0, 1.0),
) =
  ren.rect(x, y, w, h, origin, rotation, color)

proc linerect*(
    x, y, w, h: SomeNumber,
    origin = vec2(),
    rotation = 0.0,
    color = color(1.0, 1.0, 1.0, 1.0),
) =
  ren.linerect(x, y, w, h, origin, rotation, color)

proc circle*(x, y: SomeNumber, radius: SomeNumber, color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.circle(x, y, radius, color)

proc linecircle*(
    x, y: SomeNumber, radius: SomeNumber, color = color(1.0, 1.0, 1.0, 1.0)
) =
  ren.linecircle(x, y, radius, color)

proc texture*(
    texId: string,
    src: Rectangle,
    dst: Rectangle,
    origin = vec2(),
    rotation = 0.0,
    color = color(1.0, 1.0, 1.0, 1.0),
) =
  ren.texture(res.get(Texture, texId), src, dst, origin, rotation, color)

proc texture*(
    texId: string,
    pos: Vec2,
    scale = 1.0,
    origin = vec2(),
    rotation = 0.0,
    color = color(1.0, 1.0, 1.0, 1.0),
) =
  var tex = res.get(Texture, texId)
  var (w, h) = tex.size()
  ren.texture(
    tex,
    (x: 0.0, y: 0.0, w: w, h: h),
    (x: pos.x.float, y: pos.y.float, w: w * scale, h: h * scale),
    origin,
    rotation,
    color,
  )

proc texture*(
    tex: TexturePtr,
    src: Rectangle,
    dst: Rectangle,
    origin = vec2(),
    rotation = 0.0,
    color = color(1.0, 1.0, 1.0, 1.0),
) =
  ren.texture(Texture.init(tex), src, dst, origin, rotation, color)

template withDrawing*(blk: untyped) =
  beginDrawing()
  blk
  endDrawing()
