import sdl3, prelude
import std / [ os, strutils, sugar, algorithm, sequtils, json ]

import stb_image/read as stbi
import stb_image/write as stbw

type 
  Texture* = object
    p*: SDL_Texture

  Surface* = object
    p*: ptr SDL_Surface

  ScaleMode* = enum
    nearest = SDL_SCALEMODE_NEAREST
    linear = SDL_SCALEMODE_LINEAR

  TextureAtlasImage* = object
    name*: string
    x*, y*, w*, h*: int

  TextureAtlas* = object
    outFile*, imageDir*: string
    images: seq[TextureAtlasImage]

proc getImage* (atlas: TextureAtlas, name: string): Option[TextureAtlasImage] =
  result = none(TextureAtlasImage)
  for img in atlas.images:
    if img.name == name:
      return some(img)

proc `=copy`* (dest: var Texture; source: Texture) {.error.}
proc `=dup`* (source: Texture): Texture {.error.}
proc `=destroy`* (t: Texture) =
  if t.p.isNil:
    return
  SDL_DestroyTexture(t.p)

proc `=copy`* (dest: var Surface; source: Surface) {.error.}
proc `=dup`* (source: Surface): Surface {.error.}
proc `=destroy`* (t: Surface) =
  if t.p.isNil:
    return
  SDL_DestroySurface(t.p)

proc size* (t: Texture): tuple[ w, h: float ] =
  var w, h: cfloat
  discard SDL_GetTextureSize(t.p, w, h)
  result = (w.float, h.float)

proc width* (t: Texture): float = t.size.w
proc height* (t: Texture): float = t.size.h

proc sdlTexture* (t: Texture): auto = t.p

proc loadTexture* (renderer: SDL_Renderer, path: string, scaleMode: ScaleMode = nearest): Texture =
  var width, height, channels: int
  var data: seq[uint8]
  data = stbi.load(path, width, height, channels, stbi.Default)

  let sdlTexture = SDL_CreateTexture(
    renderer,
    SDL_PIXELFORMAT_RGBA32,
    SDL_TEXTUREACCESS_STREAMING,
    width.cint,
    height.cint
  )
  discard SDL_SetTextureScaleMode(sdlTexture, scaleMode.SDL_ScaleMode)
  if sdlTexture.isNil:
    let s = $SDL_GetError()
    raiseError(s)

  var rec = SDL_Rect(x: 0, y: 0, w: width.cint, h: height.cint)
  discard SDL_UpdateTexture(sdlTexture, addr rec, addr data[0], 1)

  result = Texture(p: sdlTexture)

proc write* (atlas: TextureAtlas, path: string) =
  let js = %* atlas
  writeFile(path, js.pretty)

proc read* (T: type TextureAtlas, path: string): TextureAtlas =
  let contents = readFile(path)
  result = contents.parseJson.to(TextureAtlas)

proc generateTextureAtlas* (imageDir, outPath: string): TextureAtlas =
  result = TextureAtlas(
    imageDir: imageDir,
    outFile: outPath
  )

  var surfaces = newSeq[(int, int, string, ptr SDL_Surface)]()

  for (kind, path) in walkDir(imageDir):
    if kind == pcFile:
      if not path.endsWith(".png"):
        continue
      var width, height, channels: int
      var data: seq[byte]
      data = stbi.load(path, width, height, channels, stbi.Default)

      var surface = SDL_CreateSurface(width.cint, height.cint, SDL_PIXELFORMAT_RGBA32)

      for x in 0 ..< width:
        for y in 0 ..< height:
          let r = data[(x + y * width) * 4 + 0].uint8
          let g = data[(x + y * width) * 4 + 1].uint8
          let b = data[(x + y * width) * 4 + 2].uint8
          let a = data[(x + y * width) * 4 + 3].uint8
          discard SDL_WriteSurfacePixel(surface, x.cint, y.cint, r, g, b, a)
      
      surfaces.add((width, height, path, surface))

  surfaces.sort((a, b) => (b[0] + b[1]).cmp(a[0] + a[1]))

  var 
    finalSurface = SDL_CreateSurface(512, 512, SDL_PIXELFORMAT_RGBA32)
    cursorX = 0 
    cursorY = 0
    maxHeight = 0

  for (width, height, path, surface) in surfaces:
    if cursorX + width > 512:
      cursorX = 0
      cursorY += maxHeight
      maxHeight = 0

    maxHeight = max(height, maxHeight)
    var 
      target = SDL_Rect(x: 0, y: 0, w: width.cint, h: height.cint)
      dst = SDL_Rect(x: cursorX.cint, y: cursorY.cint, w: width.cint, h: height.cint)

    result.images.add(TextureAtlasImage(
      name: path.extractFilename().replace(".png", ""), 
      x: cursorX,
      y: cursorY,
      w: width,
      h: height
    ))

    discard SDL_BlitSurface(
      surface, 
      target.addr,
      finalSurface,
      dst.addr,
    )
    cursorX += width

  let pixels = finalSurface.pixels
  let byteArray = cast[ptr UncheckedArray[byte]](pixels)
  discard stbw.writePNG(
    outPath, 
    512, 
    512, 
    4,
    toOpenArray(byteArray, 0, 512 * 512 * 4), 
  )
