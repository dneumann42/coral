import std / [ tables, logging ]

import sdl3, prelude

type
  AbstractResource* = ref object of RootObj

  Resource* [T] = ref object of AbstractResource
    asset: T 

  Texture* = object
    p: SDL_Texture

  Resources* = object
    renderer: SDL_Renderer
    res: Table[string, AbstractResource]

proc `=copy`* (dest: var Texture; source: Texture) {.error.}
proc `=dup`* (source: Texture): Texture {.error.}
proc `=destroy`* (t: Texture) =
  if t.p.isNil:
    return
  SDL_DestroyTexture(t.p)

proc size* (t: Texture): tuple[ w, h: float ] =
  var w, h: cfloat
  discard SDL_GetTextureSize(t.p, w, h)
  result = (w.float, h.float)

proc width* (t: Texture): float = t.size.w
proc height* (t: Texture): float = t.size.h

proc sdlTexture* (t: Texture): auto = t.p

proc init* (T: type Resources, renderer: SDL_Renderer): T =
  T(res: initTable[string, AbstractResource](), renderer: renderer)

proc add* [T] (self: var Resources, id: string, asset: sink T) =
  self.res[id] = Resource[T](asset: asset).AbstractResource

proc get* [T] (self: var Resources, id: string): lent T =
  result = cast[Resource[T]](self.res[id]).asset

import stb_image/read as stbi

proc loadTexture* (self: var Resources, id: string, path: string) =
  var width, height, channels: int
  var data: seq[uint8]
  data = stbi.load(path, width, height, channels, stbi.Default)

  let texture = SDL_CreateTexture(
    self.renderer, 
    SDL_PIXELFORMAT_RGBA32,
    SDL_TEXTUREACCESS_STREAMING,
    width.cint,
    height.cint
  )
  SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)

  if texture.isNil:
    let s = $SDL_GetError()
    raiseError(s)

  var rec = SDL_Rect(x: 0, y: 0, w: width.cint, h: height.cint)
  discard SDL_UpdateTexture(texture, addr rec, addr data[0], 1)

  self.add(id, Texture(p: texture))
  info("Loading '" & id & "' at " & path)

when isMainModule:
  import unittest

  test "Add & get resources":
    var res = Resources.init()
    res.add("Test", 123)
    res.add("Hello", "World")
    check get[int](res, "Test") == 123
    check get[string](res, "Hello") == "World"
