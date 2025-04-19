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

when isMainModule:
  import unittest

  test "Add & get resources":
    var res = Resources.init()
    res.add("Test", 123)
    res.add("Hello", "World")
    check get[int](res, "Test") == 123
    check get[string](res, "Hello") == "World"
