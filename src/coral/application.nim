import sdl3

import prelude, plugins, macros, macrocache
export prelude, plugins

{.push raises: [].}

type
  ApplicationConfig* = object
    width = 1280
    height = 720
    title = "Coral"

  Application* = object
    renderer: SDL_Renderer
    window: SDL_Window
    running: bool = true
    plugins*: Plugins

proc `=destroy`(app: Application) =
  SDL_Quit()

proc init* (T: type Application, config = ApplicationConfig.default()): auto {.R(Application, string).} =
  if not SDL_Init(SDL_INIT_VIDEO):
    let message = $SDL_GetError()

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

macro initializePlugins* (app: untyped): auto =
  result = nnkStmtList.newTree()
  for i in 0..<PluginCtors.len:
    let name = ident(PluginCtors[i].strVal)
    let id = PluginIds[i].strVal()
    result.add(
      quote do:
        `app`.plugins.addPlugin(`id`, `name`())
    )

proc running*(app: var Application): bool =
  var event: SDL_Event
  
  while SDL_PollEvent(event):
    case event.type:
      of SDL_EVENT_QUIT:
        app.running = false
      else:
        discard

  result = app.running 
