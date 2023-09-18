import sdl2

var
  window: WindowPtr
  sdlRenderer: RendererPtr

proc getRenderer*(): RendererPtr =
  sdlRenderer

proc setRenderer*(ren: RendererPtr) =
  sdlRenderer = ren

proc getWindow*(): WindowPtr =
  window

proc setWindow*(pt: WindowPtr) =
  window = pt

