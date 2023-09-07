import sdl2, tables, chroma, opengl
import sokol/gfx as sg

template sdlFailIf(condition: typed, reason: string) =
  if condition:
    raise newException(OSError, reason)

type KeyboardKey* {.size: sizeof(cint).} = enum
  unknown = 0,
  a = 4, b = 5, c = 6,
  d = 7, e = 8, f = 9,
  g = 10, h = 11, i = 12,
  j = 13, k = 14, l = 15,
  m = 16, n = 17, o = 18,
  p = 19, q = 20, r = 21,
  s = 22, t = 23, u = 24,
  v = 25, w = 26, x = 27,
  y = 28, z = 29, K_1 = 30,
  K_2 = 31, K_3 = 32, K_4 = 33,
  K_5 = 34, K_6 = 35, K_7 = 36,
  K_8 = 37, K_9 = 38, K_0 = 39,
  K_return = 40, K_escape = 41,
  K_backspace = 42, K_tab = 43,
  K_space = 44, K_minus = 45,
  K_equals = 46, K_leftbracket = 47,
  K_rightbracket = 48, K_backslash = 49,
  K_nonushash = 50,
  K_semicolon = 51, K_apostrophe = 52, K_grave = 53,
  K_comma = 54, K_period = 55,
  K_slash = 56, K_capslock = 57, K_f1 = 58,
  K_f2 = 59, K_f3 = 60, K_f4 = 61,
  K_f5 = 62, K_f6 = 63, K_f7 = 64,
  K_f8 = 65, K_f9 = 66, K_f10 = 67,
  K_f11 = 68, K_f12 = 69,
  K_printscreen = 70, K_scrolllock = 71,
  K_pause = 72, K_insert = 73,
  K_home = 74, K_pageup = 75,
  K_delete = 76, K_end = 77,
  K_pagedown = 78, K_right = 79,
  K_left = 80, K_down = 81, K_up = 82, K_numlockclear = 83,
  K_kp_divide = 84, K_kp_multiply = 85,
  K_kp_minus = 86, K_kp_plus = 87,
  K_kp_enter = 88, K_kp_1 = 89,
  K_kp_2 = 90, K_kp_3 = 91, K_kp_4 = 92,
  K_kp_5 = 93, K_kp_6 = 94, K_kp_7 = 95,
  K_kp_8 = 96, K_kp_9 = 97, K_kp_0 = 98,
  K_kp_period = 99, K_nonusbackslash = 100,
  K_application = 101,
  K_power = 102,
  K_kp_equals = 103, K_f13 = 104,
  K_f14 = 105, K_f15 = 106, K_f16 = 107,
  K_f17 = 108, K_f18 = 109, K_f19 = 110,
  K_f20 = 111, K_f21 = 112, K_f22 = 113,
  K_f23 = 114, K_f24 = 115,
  K_execute = 116, K_help = 117,
  K_menu = 118, K_select = 119,
  K_stop = 120, K_again = 121,
  K_undo = 122, K_cut = 123, K_copy = 124,
  K_paste = 125, K_find = 126,
  K_mute = 127, K_volumeup = 128, K_volumedown = 129,
  K_kp_comma = 133, K_kp_equalsas400 = 134, K_international1 = 135,
  K_international2 = 136, K_international3 = 137,       #*< yEN
  K_international4 = 138, K_international5 = 139,
  K_international6 = 140, K_international7 = 141,
  K_international8 = 142, K_international9 = 143, K_lang1 = 144, #*< hANGUL/eNGLISH TOGGLE
  K_lang2 = 145, K_lang3 = 146,
  K_lang4 = 147, K_lang5 = 148,
  K_lang6 = 149, K_lang7 = 150,
  K_lang8 = 151, K_lang9 = 152,
  K_alterase = 153,
  K_sysreq = 154, K_cancel = 155,
  K_clear = 156, K_prior = 157,
  K_return2 = 158, K_separator = 159,
  K_out = 160, K_oper = 161,
  K_clearagain = 162, K_crsel = 163,
  K_exsel = 164, K_kp_00 = 176,
  K_kp_000 = 177, K_thousandsseparator = 178,
  K_decimalseparator = 179, K_currencyunit = 180,
  K_currencysubunit = 181, K_kp_leftparen = 182,
  K_kp_rightparen = 183, K_kp_leftbrace = 184,
  K_kp_rightbrace = 185, K_kp_tab = 186,
  K_kp_backspace = 187, K_kp_a = 188,
  K_kp_b = 189, K_kp_c = 190, K_kp_d = 191,
  K_kp_e = 192, K_kp_f = 193,
  K_kp_xor = 194, K_kp_power = 195,
  K_kp_percent = 196, K_kp_less = 197,
  K_kp_greater = 198, K_kp_ampersand = 199,
  K_kp_dblampersand = 200, K_kp_verticalbar = 201,
  K_kp_dblverticalbar = 202, K_kp_colon = 203,
  K_kp_hash = 204, K_kp_space = 205,
  K_kp_at = 206, K_kp_exclam = 207,
  K_kp_memstore = 208, K_kp_memrecall = 209,
  K_kp_memclear = 210, K_kp_memadd = 211,
  K_kp_memsubtract = 212, K_kp_memmultiply = 213,
  K_kp_memdivide = 214, K_kp_plusminus = 215,
  K_kp_clear = 216, K_kp_clearentry = 217,
  K_kp_binary = 218, K_kp_octal = 219,
  K_kp_decimal = 220, K_kp_hexadecimal = 221,
  K_lctrl = 224, K_lshift = 225, K_lalt = 226,          #*< ALT, OPTION
  K_lgui = 227,                                         ## WINDOWS, COMMAND (APPLE), META
  K_rctrl = 228, K_rshift = 229, K_ralt = 230,          #*< ALT GR, OPTION
  K_rgui = 231,                                         ## WINDOWS, COMMAND (APPLE), META
  K_mode = 257,
  K_audionext = 258, K_audioprev = 259,
  K_audiostop = 260, K_audioplay = 261,
  K_audiomute = 262, K_mediaselect = 263,
  K_www = 264, K_mail = 265,
  K_calculator = 266, K_computer = 267,
  K_ac_search = 268, K_ac_home = 269,
  K_ac_back = 270, K_ac_forward = 271,
  K_ac_stop = 272, K_ac_refresh = 273, K_ac_bookmarks = 274,
  K_brightnessdown = 275, K_brightnessup = 276, K_displayswitch = 277,
  K_kbdillumtoggle = 278, K_kbdillumdown = 279,
  K_kbdillumup = 280, K_eject = 281, K_sleep = 282,

type
  Clock = object
    dt: float
    timer: float
    ticks: uint64

var
  window: WindowPtr
  renderer: RendererPtr
  context: GlContextPtr
  inputs: Table[KeyboardKey, bool]
  lastInputs: Table[KeyboardKey, bool]
  prev: uint64
  clock = Clock()

proc fps*(): float =
  if clock.dt == 0.0:
    return 0.0
  1.0 / clock.dt

proc toKeyboardKey(code: Scancode): KeyboardKey =
  cast[KeyboardKey](code)

proc initializeWindow*(title = "Window") =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialiation failed"

  window = createWindow(
    title = "Hello, World",
    x = SDL_WINDOWPOS_CENTERED,
    y = SDL_WINDOWPOS_CENTERED,
    w = 1280,
    h = 720,
    flags = SDL_WINDOW_SHOWN
  )

  sdlFailIf(window.isNil):
    "Window could not be created"

  context = window.glCreateContext()
  discard glSetSwapInterval(-1)

  renderer = createRenderer(
    window = window,
    index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture
  )

  sdlFailIf(renderer.isNil):
    "Renderer could not be created"

  clock.ticks = getPerformanceCounter()

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
  if not window.isNil:
    window.destroy()
  if not renderer.isNil:
    renderer.destroy()

proc deltaTime*(): float =
  clock.dt

proc updateWindow*(): bool =
  result = true

  var event = defaultEvent

  for key in inputs.keys:
    lastInputs[key] = inputs[key]

  clock.ticks = getPerformanceCounter()
  clock.dt = (clock.ticks - prev).float64 / getPerformanceFrequency().float64
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
  discard

proc endDrawing() =
  window.glSwapWindow()
  # renderer.present()

template withDrawing*(blk: untyped) =
  beginDrawing()
  blk
  endDrawing()

template pushColor(color = color(0.0, 0.0, 0.0, 1.0), blk: untyped) =
  var last: ColorRGBA
  var rgba = color.rgba
  renderer.getDrawColor(last.r, last.g, last.b, last.a)
  renderer.setDrawColor(rgba.r, rgba.g, rgba.b, rgba.a)
  blk
  renderer.setDrawColor(last.r, last.g, last.b, last.a)

proc clearBackground*(color = color(0.0, 0.0, 0.0, 1.0)) =
  pushColor(color):
    renderer.clear()
