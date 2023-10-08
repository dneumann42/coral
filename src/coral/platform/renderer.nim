import sdl2, vmath, chroma, tables, cascade
import sdl2/[gfx, image, ttf]
import std/[logging, md5]
import fusion/matching
import resources, state, options

type
  Rectangle* = tuple[x, y, w, h: float]
  Renderer* = object
    texts: Table[string, TexturePtr]
  Camera* = object
    position*, origin*: Vec2
    rotation*: float
    zoom* = 1.0

  Canvas* = TexturePtr

var activeCamera: Option[Camera]

proc toSDLRect*(r: Rectangle): Rect =
  rect(r.x.cint, r.y.cint, r.w.cint, r.h.cint)

proc windowSize*(): Vec2 =
  var w, h: cint
  getWindow().getSize(w, h)
  result = vec2(w.float, h.float)

proc init*(T: type Renderer): T =
  T(texts: initTable[string, TexturePtr]())

proc init*(T: type Canvas, width, height: SomeInteger): T =
  result = getRenderer().createTexture(
    SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, width.int32, height.int32
  )

proc size*(tex: TexturePtr): (int, int) =
  var w, h: cint
  tex.queryTexture(nil, nil, w.addr, h.addr)
  (w.int, h.int)

proc setCamera*(camera: Camera) =
  activeCamera = some(camera)

proc unsetCamera*() =
  activeCamera = none(Camera)

template pushColor*(ren: Renderer, color = color(0.0, 0.0, 0.0, 1.0),
    blk: untyped) =
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

proc offsetZoom*(pos: Vec2): (Vec2, float) =
  let sz = renderer.windowSize()
  if Some(@cam) ?= activeCamera:
    ((pos - cam.position) * cam.zoom + sz / 2.0, cam.zoom)
  else:
    (pos, 1.0)

proc getTransformedRect(x, y, w, h: SomeNumber): Rect =
  var (pos, zoom) = offsetZoom(vec2(x.float, y.float))
  rect(
    cint(pos.x),
    cint(pos.y),
    cint(w.float * zoom),
    cint(h.float * zoom)
  )

proc rect*(
  ren: Renderer,
  x, y,
  w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.pushColor(color):
    var r = getTransformedRect(x, y, w, h)
    getRenderer().fillRect(r)

proc linerect*(
  ren: Renderer,
  x, y,
  w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.pushColor(color):
    var r = getTransformedRect(x, y, w, h)
    getRenderer().drawRect(r)

proc circle*(
  ren: Renderer,
  x, y: SomeNumber,
  radius: SomeNumber,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  let c = color.rgba
  let (pos, zoom) = offsetZoom(vec2(x.float, y.float))
  getRenderer().filledCircleRGBA(
    int16(pos.x), int16(pos.y), int16(radius * zoom),
    c.r, c.g, c.b, c.a)

proc measureString*(font: Font, text: string): Vec2 =
  var w, h: cint
  discard sizeText(font.fontPtr, text.cstring, w.addr, h.addr)
  result = vec2(w.float, h.float)

proc text*(
  ren: var Renderer,
  tex: string,
  font: Font,
  x, y: SomeNumber
) =
  var texture = block:
    let id = $tex.toMD5
    if ren.texts.hasKey(id):
      ren.texts[id]
    else:
      var surface = renderTextSolid(
        font.fontPtr,
        tex.cstring,
        (r: 255.uint8, g: 255.uint8, b: 255.uint8, a: 255.uint8))
      var tex = getRenderer().createTextureFromSurface(surface)
      freeSurface(surface)
      ren.texts[id] = tex
      tex

  var (w, h) = texture.size()
  let (pos, _) = offsetZoom(vec2(x.float, y.float))

  var d = (floor(pos.x.float), floor(pos.y.float), w.float, h.float).toSDLRect()
  var p = point(0, 0)

  getRenderer().copyEx(
    texture,
    nil,
    d.addr,
    0.0,
    p.addr,
    0
  )

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

  let (pos, zoom) = offsetZoom(vec2(d.x.float, d.y.float))

  d.x = pos.x.cint
  d.y = pos.y.cint
  d.w = (d.w.float * zoom).int32
  d.h = (d.h.float * zoom).int32

  var p = point(0, 0)
  ren.pushColor(color):
    getRenderer().copyEx(
      tex.texPtr,
      s.addr,
      d.addr,
      rotation,
      p.addr,
      0
    )
