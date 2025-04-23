import std / [ options, oids, sets, tables ]

import sdl3, bumpy
import resources, palette

type
  Camera* = object
    x*, y*: float

  Artist* = object
    renderer: SDL_Renderer

    canvases: seq[Canvas]
    camera*: Camera
    cursors: Table[SDL_SystemCursor, SDL_Cursor]

    drawDebugCanvasBorders = false

  Canvas* = ref object
    uid: Oid
    layer: int
    color*: SDL_FColor
    width*, height*: int
    windowWidth*, windowHeight*: int
    texture: SDL_Texture
    shouldRender*: bool
    camera*: Camera

  SystemCursorKind* = enum
    defaultCursor = SDL_SYSTEM_CURSOR_DEFAULT
    text = SDL_SYSTEM_CURSOR_TEXT
    wait = SDL_SYSTEM_CURSOR_WAIT
    crosshair = SDL_SYSTEM_CURSOR_CROSSHAIR
    progress = SDL_SYSTEM_CURSOR_PROGRESS
    nwseResize = SDL_SYSTEM_CURSOR_NWSE_RESIZE
    neswResize = SDL_SYSTEM_CURSOR_NESW_RESIZE
    ewResize = SDL_SYSTEM_CURSOR_EW_RESIZE
    nsResize = SDL_SYSTEM_CURSOR_NS_RESIZE
    move = SDL_SYSTEM_CURSOR_MOVE
    notAllowed = SDL_SYSTEM_CURSOR_NOT_ALLOWED  
    pointer = SDL_SYSTEM_CURSOR_POINTER      
    nwResize = SDL_SYSTEM_CURSOR_NW_RESIZE    
    nResize = SDL_SYSTEM_CURSOR_N_RESIZE     
    neresize = SDL_SYSTEM_CURSOR_NE_RESIZE    
    eResize = SDL_SYSTEM_CURSOR_E_RESIZE     
    seResize = SDL_SYSTEM_CURSOR_SE_RESIZE    
    sResize = SDL_SYSTEM_CURSOR_S_RESIZE     
    swResize = SDL_SYSTEM_CURSOR_SW_RESIZE    
    wResize = SDL_SYSTEM_CURSOR_W_RESIZE     
    count = SDL_SYSTEM_CURSOR_COUNT

proc windowSize(artist: Artist): (int, int) =
  let window = SDL_GetRenderWindow(artist.renderer)
  var 
    w: cint = 640
    h: cint = 480
  discard SDL_GetWindowSize(window, w, h)
  result = (w, h)

proc init* (T: type Artist, renderer: SDL_Renderer): T =
  result = T(
    renderer: renderer,
    cursors: initTable[SDL_SystemCursor, SDL_Cursor](),
  )
  for cursor in low(SDL_SystemCursor) .. high(SDL_SystemCursor):
    var systemCursor = SDL_CreateSystemCursor(cursor)
    result.cursors[cursor] = systemCursor

proc deinit* (artist: Artist) =
  for cursor in artist.cursors.values:
    SDL_DestroyCursor(cursor)

proc init* (T: type Canvas, width, height: int, layer = 0): T =
  result = T(
    uid: genOid(),
    layer: layer,
    width: width,
    height: height
  )

proc setSystemCursor* (artist: Artist, kind: SystemCursorKind) =
  var cursor = artist.cursors[cast[SDL_SystemCursor](kind)] 
  discard SDL_SetCursor(cursor)

proc resetSystemCursor* (artist: Artist) =
  discard SDL_SetCursor(artist.cursors[cast[SDL_SystemCursor](defaultCursor)])

proc newCanvas* (artist: var Artist, width, height: int, layer = 0): Canvas =
  let (ww, wh) = artist.windowSize()
  result = Canvas.init(width, height, layer)
  # TODO: handle error
  result.texture = SDL_CreateTexture(
    artist.renderer, 
    SDL_PIXELFORMAT_RGBA32, 
    SDL_TEXTUREACCESS_TARGET, 
    width.cint, 
    height.cint,
  )
  result.windowWidth = ww
  result.windowHeight = wh
  result.color = SDL_FColor(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
  SDL_SetTextureScaleMode(result.texture, SDL_SCALEMODE_NEAREST)
  artist.canvases.add(result)

proc setColor* (artist: Artist, color = White) =
  SDL_SetRenderDrawColorFloat(artist.renderer, color.r, color.g, color.b, color.a)

proc `color=`* (artist: Artist, color: SDL_FColor) = 
  artist.setColor(color)

proc color* (artist: Artist): SDL_FColor =
  result = SDL_FColor(r: 0.0, g: 0.0, b: 0.0, a: 0.0)
  discard SDL_GetRenderDrawColorFloat(artist.renderer, result.r, result.g, result.b, result.a)

var 
  canvasWidthL = 0 
  canvasHeightL = 0
  cameraX = 0.0
  cameraY = 0.0

proc canvasWidth* (artist: Artist): int =
  result = canvasWidthL
proc canvasHeight* (artist: Artist): int =
  result = canvasHeightL

proc setCanvas* (artist: Artist, canvas: var Canvas) =
  let (ww, wh) = artist.windowSize()
  if not SDL_SetRenderTarget(artist.renderer, canvas.texture):
    raise CatchableError.newException($SDL_GetError())
  artist.color = canvas.color
  canvas.shouldRender = true
  canvas.windowWidth = ww
  canvas.windowHeight = wh
  canvasWidthL = canvas.width
  canvasHeightL = canvas.height
  cameraX = canvas.camera.x
  cameraY = canvas.camera.y
  SDL_RenderClear(artist.renderer)

proc canvasScale* (canvas: Canvas): tuple[x, y: float] =
  result = (
    canvas.width.toFloat / max(canvas.windowWidth.toFloat, 0.001),
    canvas.height.toFloat / max(canvas.windowHeight.toFloat, 0.001)
  )

proc unsetCanvas* (artist: Artist) =
  discard SDL_SetRenderTarget(artist.renderer, nil)

template canvas* (artist: Artist, canvas: var Canvas, blk: untyped): auto =
  artist.setCanvas(canvas)
  block:
    blk
  artist.unsetCanvas()

proc endRender(artist: var Artist) =
  for canvas in artist.canvases.mitems:
    canvas.shouldRender = false

proc rect* (artist: Artist, x, y, w, h: float, color = White, filled = false)

proc render* (artist: var Artist) =
  let window = SDL_GetRenderWindow(artist.renderer)

  var (w, h) = artist.windowSize()

  var chh = 0.0
  for canvas in artist.canvases:
    chh = max(chh, canvas.height.toFloat())

  for canvas in artist.canvases.mitems:
    if not canvas.shouldRender:
      continue
  
    let 
      scale = (if chh == 0: 0.0 else: h.toFloat() / chh)
      cw = canvas.width.toFloat() * scale
      ch = canvas.height.toFloat() * scale

    let x = w.toFloat / 2.0 - cw / 2.0
    let y = h.toFloat / 2.0 - ch / 2.0

    canvas.shouldRender = false
    var 
      src = SDL_FRect(
        x: 0.0, y: 0.0, w: canvas.width.toFloat(), h: canvas.height.toFloat())
      dst = SDL_FRect(x: x, y: y, w: cw, h: ch)
    discard SDL_RenderTexture(
      artist.renderer,
      canvas.texture,
      src.addr,
      dst.addr,
    )
    if artist.drawDebugCanvasBorders:
      artist.rect(x, y, cw, ch)

proc transform(artist: Artist, x, y: float): tuple[x, y: float] =
  result = (x - cameraX, y - cameraY)

proc rect* (artist: Artist, x, y, w, h: float, color = White, filled = false) =
  let (x, y) = artist.transform(x, y)
  artist.color = color
  if filled:
    SDL_RenderFillRect(artist.renderer, SDL_FRect(x: x.cfloat, y: y.cfloat, w: w.cfloat, h: h.cfloat))
  else:
    SDL_RenderRect(artist.renderer, SDL_FRect(x: x.cfloat, y: y.cfloat, w: w.cfloat, h: h.cfloat))

proc rect* (artist: Artist, r: Rect, color = White, filled = false) =
  let (x, y) = artist.transform(r.x, r.y)
  artist.rect(x, y, r.w, r.h, color, filled)

proc debugText* (artist: Artist, text: string, x, y: SomeNumber, color = White) =
  let (x, y) = artist.transform(x, y)
  artist.color = color
  discard SDL_RenderDebugText(artist.renderer, x.cfloat, y.cfloat, text.cstring)

proc line* (artist: Artist, x1, y1, x2, y2: SomeNumber, color = White) =
  let (x1, y1) = artist.transform(x1, y1)
  let (x2, y2) = artist.transform(x2, y2)
  artist.color = color
  SDL_RenderLine(artist.renderer, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat)

proc image* (artist: Artist, dest: Rect, texture: Texture, region = none(Rect), color = White) =
  artist.color = color
  let (x, y) = artist.transform(dest.x, dest.y)
  let r = region.get(rect(0.0, 0.0, texture.width.cfloat, texture.height.cfloat))
  var 
    s = SDL_FRect(x: x, y: y, w: dest.w, h: dest.h)
    d = SDL_FRect(x: r.x, y: r.y, w: r.w, h: r.h)
  discard SDL_RenderTexture(artist.renderer, texture.sdlTexture(), d.addr, s.addr)
