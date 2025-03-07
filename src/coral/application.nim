import sdl3

import prelude, plugins, macros, macrocache
export prelude, plugins

{.push raises: [].}

type
  ApplicationConfig* = object
    width* = 1280
    height* = 720
    title* = "Coral"

  Application* = object
    renderer: SDL_Renderer
    window: SDL_Window
    running: bool = true
    plugins*: Plugins

proc `=destroy`(app: Application) =
  SDL_Quit()

proc init* (T: type Application, config = ApplicationConfig.default()): auto {.R(Application, string).} =
  if not SDL_Init(SDL_INIT_VIDEO):
    return Err($SDL_GetError())

  let window = SDL_CreateWindow(config.title.cstring, config.width, config.height, 0)
  if window.isNil:
    return Err($SDL_GetError())

  let renderer = SDL_CreateRenderer(window, nil)
  if renderer.isNil:
    return Err($SDL_GetError())

  var plugins = Plugins()

  result = Ok(T(
    renderer: renderer,
    window: window,
    plugins: plugins
  ))

proc add*(app: var Application, plugin: Plugin): var Application {.discardable.} =
  app.plugins.add(plugin)
  app

proc running* (app: var Application): bool =
  var event: SDL_Event

  while SDL_PollEvent(event):
    case event.type:
      of SDL_EVENT_QUIT:
        app.running = false
      else:
        discard

  result = app.running 

proc beginFrame* (app: var Application) =
  SDL_SetRenderDrawColorFloat(app.renderer, 0.0, 0.0, 0.0, 1.0)
  SDL_RenderClear(app.renderer)

proc endFrame* (app: var Application) =
  SDL_RenderPresent(app.renderer)
