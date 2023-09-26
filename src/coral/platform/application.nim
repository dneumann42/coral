import sdl2, tables, chroma, opengl, vmath, std/logging
import state, resources, renderer, keys
import sdl2/ttf

template sdlFailIf(condition: typed, reason: string) =
  if condition:
    raise newException(OSError, reason)

var consoleLog = newConsoleLogger()
var fileLog = newFileLogger("errors.log", levelThreshold = lvlError)

addHandler(consoleLog)
addHandler(fileLog)

type
  Clock = object
    dt: float
    timer: float
    ticks: uint64

var
  ren: Renderer
  res: Resources
  context: GlContextPtr
  inputs: Table[KeyboardKey, bool]
  lastInputs: Table[KeyboardKey, bool]
  prev: uint64
  clock = Clock()

proc fps*(): float =
  if clock.dt == 0.0:
    return 0.0
  1.0 / clock.dt

proc clockTimer*(): float =
  clock.timer

proc toKeyboardKey(code: Scancode): KeyboardKey =
  cast[KeyboardKey](code)

proc initializeWindow*(title = "Window") =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialiation failed"

  sdlFailIf(ttfInit() == False32, "SDL2 TTF failed to initialize")

  setWindow(createWindow(
    title = "Hello, World",
    x = SDL_WINDOWPOS_CENTERED,
    y = SDL_WINDOWPOS_CENTERED,
    w = 1280,
    h = 720,
    flags = SDL_WINDOW_SHOWN
  ))

  sdlFailIf(getWindow().isNil):
    "Window could not be created"

  context = getWindow().glCreateContext()
  discard glSetSwapInterval(-1)

  setRenderer(createRenderer(
    window = getWindow(),
    index = 0,
    flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture
  ))

  sdlFailIf(getRenderer().isNil):
    "Renderer could not be created"

  clock.ticks = getPerformanceCounter()
  ren = Renderer.init()
  res = Resources.init()

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

  clock.ticks = getPerformanceCounter()
  clock.dt = (clock.ticks - prev).float64 / getPerformanceFrequency().float64
  clock.timer += clock.dt
  prev = clock.ticks

  while pollEvent(event):
    case event.kind
    of QuitEvent:
      return false
    of KeyDown:
      inputs[event.key.keysym.scancode.toKeyboardKey] = true
    of KeyUp:
      inputs[event.key.keysym.scancode.toKeyboardKey] = false
    else:
      discard

proc beginDrawing() =
  ren.beginDrawing()

proc endDrawing() =
  ren.endDrawing()

proc startCanvas*(canvas: Canvas) =
  getRenderer().setRenderTarget(canvas)
  canvas.setTextureBlendMode(BLENDMODE_BLEND)
  ren.pushColor(color(0.0, 0.0, 0.0, 0.0)):
    getRenderer().clear()

proc endCanvas*() =
  getRenderer().setRenderTarget(nil)

proc loadImage*(path, id: string) = res.load(Texture, path, id)
proc loadFont*(path, id: string, size: int) = res.load(Font, path, id, size)

proc loadImage*(path: string) =
  res.load(Texture, path, path.extractFilenameWithoutExt())
proc loadFont*(path: string, size: int) = 
  res.load(Font, path, path.extractFilenameWithoutExt(), size)

# TODO: make fontId distinct so accedental assignment is prevented
proc measureString*(text: string, fontId: string): Vec2 =
  result = res.get(Font, fontId).measureString(text)

proc text*(
  tex: string,
  fontId: string,
  x, y: SomeNumber
) =
  ren.text(tex, res.get(Font, fontId), x, y)

proc rect*(
  x, y, w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.rect(x, y, w, h, origin, rotation, color)

proc linerect*(
  x, y, w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.linerect(x, y, w, h, origin, rotation, color)

proc circle*(
  x, y: SomeNumber,
  radius: SomeNumber,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.circle(x, y, radius, color)

proc texture*(
  texId: string,
  src: Rectangle,
  dst: Rectangle,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.texture(res.get(Texture, texId), src, dst, origin, rotation, color)

proc texture*(
  tex: TexturePtr,
  src: Rectangle,
  dst: Rectangle,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.texture(Texture.init(tex), src, dst, origin, rotation, color)

template withDrawing*(blk: untyped) =
  beginDrawing()
  blk
  endDrawing()
