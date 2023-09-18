import sdl2, vmath, chroma, tables
import sdl2/[gfx, image]
import std/logging
import resources, state

type 
  Rectangle* = tuple[x, y, w, h: float]
  Renderer* = object
  Camera* = object
  Canvas* = TexturePtr

proc toSDLRect(r: Rectangle): Rect =
  rect(r.x.cint, r.y.cint, r.w.cint, r.h.cint)

proc init*(T: type Renderer): T =
  T()

proc init*(T: type Canvas, width, height: SomeInteger): T =
  getRenderer().createTexture(
    SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, width.int32, height.int32
  )

proc size*(canvas: Canvas): (int, int) =
  var w, h: cint
  canvas.queryTexture(nil, nil, w.addr, h.addr)
  (w.int, h.int)

template pushColor*(ren: Renderer, color = color(0.0, 0.0, 0.0, 1.0), blk: untyped) =
  var last: ColorRGBA
  var rgba = color.rgba
  getRenderer().getDrawColor(last.r, last.g, last.b, last.a)
  getRenderer().setDrawColor(rgba.r, rgba.g, rgba.b, rgba.a)
  blk
  getRenderer().setDrawColor(last.r, last.g, last.b, last.a)

proc beginDrawing*(ren: Renderer) =
  ren.pushColor(color(0.2, 0.2, 0.2, 1.0)):
    getRenderer().clear()

proc endDrawing*(ren: Renderer) =
  getRenderer().present()

proc rect*(
  ren: Renderer,
  x, y,
  w, h: SomeNumber,
  origin = vec2(), 
  rotation = 0.0, 
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.pushColor(color):
    var r = rect(
      cint(x), cint(y),
      cint(w), cint(h)
    )
    getRenderer().fillRect(r)

proc circle*(
  ren: Renderer, 
  x, y: SomeNumber, 
  radius: SomeNumber,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  let c = color.rgba
  getRenderer().filledCircleRGBA(
    int16(x), int16(y), int16(radius),
    c.r, c.g, c.b, c.a)

proc texture*(
  ren: Renderer,
  tex: Texture,
  src: Rectangle,
  dst: Rectangle,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  var s = src.toSDLRect()
  var d = dst.toSDLRect()
  var p = point(0, 0)
  getRenderer().copyEx(
    tex.texPtr,
    s.addr, 
    d.addr,
    rotation,
    p.addr,
    0
  )
