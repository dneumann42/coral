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

proc toSDLRect(r: Rectangle): Rect =
  rect(r.x.cint, r.y.cint, r.w.cint, r.h.cint)

proc init*(T: type Renderer): T =
  T(texts: initTable[string, TexturePtr]())

proc init*(T: type Canvas, width, height: SomeInteger): T =
  getRenderer().createTexture(
    SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, width.int32, height.int32
  )

proc size*(tex: TexturePtr): (int, int) =
  var w, h: cint
  tex.queryTexture(nil, nil, w.addr, h.addr)
  (w.int, h.int)

# proc setCameraPosition*(pos: Vec2) =
#   if Some(@cam) ?= activeCamera:
#     activeCamera = some(
#       cascade(cam) do:
#       position = pos
#     )

# proc getCameraPosition*(): Vec2 =
#   if Some(@cam) ?= activeCamera:
#     cam.position
#   else:
#     vec2()

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

proc offset*(): Vec2 =
  if Some(@cam) ?= activeCamera:
    -cam.position
  else:
    vec2()

proc rect*(
  ren: Renderer,
  x, y,
  w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.pushColor(color):
    let off = offset()
    var r = rect(
      cint(x + off.x), cint(y + off.y),
      cint(w), cint(h)
    )
    getRenderer().fillRect(r)

proc linerect*(
  ren: Renderer,
  x, y,
  w, h: SomeNumber,
  origin = vec2(),
  rotation = 0.0,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  ren.pushColor(color):
    let off = offset()
    var r = rect(
      cint(x + off.x), cint(y + off.y),
      cint(w), cint(h)
    )
    getRenderer().drawRect(r)

proc circle*(
  ren: Renderer,
  x, y: SomeNumber,
  radius: SomeNumber,
  color = color(1.0, 1.0, 1.0, 1.0)) =
  let c = color.rgba
  let off = offset()
  getRenderer().filledCircleRGBA(
    int16(x + off.x), int16(y + off.y), int16(radius),
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
  let off = offset()

  var d = (x.float + off.x, y.float + off.y, w.float, h.float).toSDLRect()
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
  let off = offset()
  var s = src.toSDLRect()
  var d = dst.toSDLRect()
  d.x += off.x.cint
  d.y += off.y.cint
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
