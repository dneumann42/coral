import std / [ tables, logging ]
import atlas
export atlas

import sdl3, prelude

type
  AbstractResource* = ref object of RootObj

  Resource* [T] = ref object of AbstractResource
    asset: T 

  Resources* = ref object
    renderer: SDL_Renderer
    res: Table[string, AbstractResource]

proc init* (T: type Resources, renderer: SDL_Renderer): T =
  T(res: initTable[string, AbstractResource](), renderer: renderer)

proc add* [T] (self: Resources, id: string, asset: sink T) =
  self.res[id] = Resource[T](asset: asset).AbstractResource

proc get* [T] (self: Resources, id: string): lent T =
  result = cast[Resource[T]](self.res[id]).asset

import stb_image/read as stbi

proc loadTexture* (self: Resources, id: string, path: string) =
  self.add(id, self.renderer.loadTexture(path))
  info("Loading '" & id & "' at " & path)

proc loadTextureAtlas* (self: Resources, id: string, path: string) =
  let atlas = TextureAtlas.read(path)
  self.add(id, atlas)
  self.loadTexture(id & "_texture", atlas.outFile)
  info("Loading '" & id & "' at " & path)
