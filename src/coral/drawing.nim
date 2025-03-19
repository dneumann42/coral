import std / [ options ]

import sdl3, bumpy
import resources

const White* = SDL_FColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0)

type
  Camera* = object
    x*, y*: float

  Artist* = object
    renderer: SDL_Renderer
    canvases: seq[Canvas]
    camera*: Camera

  Canvas* = object
    layer: int
    color*: SDL_FColor
    width, height: int
    texture: SDL_Texture

  Color* = SDL_FColor

proc init* (T: type Artist, renderer: SDL_Renderer): T =
  result = T(
    renderer: renderer,
  )

proc init* (T: type Canvas, width, height: int, layer = 0): T =
  result = T(
    layer: layer,
    width: width,
    height: height
  )

proc newCanvas* (artist: var Artist, width, height: int, layer = 0): Canvas =
  result = Canvas.init(width, height, layer)
  # TODO: handle error
  result.texture = SDL_CreateTexture(
    artist.renderer, 
    SDL_PIXELFORMAT_RGBA32, 
    SDL_TEXTUREACCESS_TARGET, 
    width.cint, 
    height.cint
  )
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

proc setCanvas* (artist: Artist, canvas: Canvas) =
  if not SDL_SetRenderTarget(artist.renderer, canvas.texture):
    raise CatchableError.newException($SDL_GetError())
  artist.color = canvas.color
  SDL_RenderClear(artist.renderer)

proc unsetCanvas* (artist: Artist) =
  discard SDL_SetRenderTarget(artist.renderer, nil)

template canvas* (artist: Artist, canvas: Canvas, blk: untyped): auto =
  artist.setCanvas(canvas)
  block:
    blk
  artist.unsetCanvas()

proc render* (artist: Artist) =
  let window = SDL_GetRenderWindow(artist.renderer)

  var 
    w: cint = 640
    h: cint = 480
  discard SDL_GetWindowSize(window, w, h)

  for canvas in artist.canvases:
    var 
      src = SDL_FRect(x: 0.0, y: 0.0, w: canvas.width.toFloat(), h: canvas.height.toFloat())
      dst = SDL_FRect(x: 0.0, y: 0.0, w: w.toFloat(), h: h.toFloat())
    discard SDL_RenderTexture(
      artist.renderer,
      canvas.texture,
      src.addr,
      dst.addr,
    )

proc transform(artist: Artist, x, y: SomeNumber): (SomeNumber, SomeNumber) =
  result = (x - artist.camera.x, y - artist.camera.y)

proc rect* (artist: Artist, x, y, w, h: SomeNumber, color = White, filled = false) =
  let (xx, yy) = artist.transform(x, y)
  artist.color = color
  if filled:
    SDL_RenderFillRect(artist.renderer, SDL_FRect(x: xx.cfloat, y: yy.cfloat, w: w.cfloat, h: h.cfloat))
  else:
    SDL_RenderRect(artist.renderer, SDL_FRect(x: xx.cfloat, y: yy.cfloat, w: w.cfloat, h: h.cfloat))

proc circle* (artist: Artist, x, y, r: SomeNumber, color = White, filled = false) =
  let (xx, yy) = artist.transform(x, y)
  discard

proc debugText* (artist: Artist, text: string, x, y: SomeNumber, color = White) =
  let (xx, yy) = artist.transform(x, y)
  artist.color = color
  discard SDL_RenderDebugText(artist.renderer, xx.cfloat, yy.cfloat, text.cstring)

proc line* (artist: Artist, x1, y1, x2, y2: SomeNumber, color = White) =
  let (x1, y1) = artist.transform(x1, y1)
  let (x2, y2) = artist.transform(x2, y2)
  artist.color = color
  SDL_RenderLine(artist.renderer, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat)

proc image* (artist: Artist, dest: Rect, texture: Texture, region = none(Rect), color = White) =
  artist.color = color
  let r = region.get(rect(0.0, 0.0, texture.width.cfloat, texture.height.cfloat))
  var 
    s = SDL_FRect(x: dest.x, y: dest.y, w: dest.w, h: dest.h)
    d = SDL_FRect(x: r.x, y: r.y, w: r.w, h: r.h)
  discard SDL_RenderTexture(artist.renderer, texture.sdlTexture(), d.addr, s.addr)
