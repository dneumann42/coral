import std / [ options, sequtils ]

import sdl3

import prelude, plugins, drawing, actions, appcommands, macros
export prelude, plugins, drawing, actions

{.push raises: [].}

type
  ApplicationConfig* = object
    width* = 640 * 2
    height* = 480 * 2
    title* = "Coral"

  Application* = object
    renderer: SDL_Renderer
    window: SDL_Window
    running: bool = true
    sceneStack: seq[string]
    plugins*: Plugins
    artist*: Artist

proc `=destroy`(app: Application) =
  SDL_Quit()

proc init* (T: type Application, config = ApplicationConfig.default()): auto {.R(Application, string).} =
  if not SDL_Init(SDL_INIT_VIDEO):
    return Err($SDL_GetError())

  discard SDL_ScaleMode(SDL_SCALEMODE_NEAREST)
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
    plugins: plugins,
    sceneStack: @[],
    artist: Artist.init(renderer)
  ))

proc push* (app: var Application, sceneId: string): var Application {.discardable.} =
  app.sceneStack.add(sceneId)
  app

proc pop* (app: var Application): Option[string] =
  if app.sceneStack.len() == 0:
    return
  result = app.sceneStack[^1].some()

proc goto* (app: var Application, sceneId: string): var Application {.discardable.} =
  discard app.pop()
  app.push(sceneId)

proc currentScene* (app: Application): string =
  result = app.sceneStack[^1]

proc add* [T: Plugin] (app: var Application, plugin: T): var Application {.discardable.} =
  app.plugins.add(plugin)
  app

proc running* (app: var Application): bool =
  var event: SDL_Event

  while SDL_PollEvent(event):
    case event.type:
      of SDL_EVENT_QUIT:
        app.running = false
      of SDL_EVENT_KEY_DOWN:
        handleKeyPressed(cast[Keycode](event.key.key))
      of SDL_EVENT_KEY_UP:
        handleKeyReleased(cast[Keycode](event.key.key))
      else:
        discard

  result = app.running 

proc load* (app: var Application) {.raises: [Exception].} =
  for plugin in app.plugins.plugins:
    plugin.load()

proc update* (app: var Application) {.raises: [Exception].} =
  defer: updateActions()

  var commands = newSeq[Command]()
  for plugin in app.plugins.mplugins:
    if plugin.isScene and plugin.id != app.currentScene():
      continue
    plugin.update()
    for cmd in plugin.cmds:
      commands.add(cmd)
    plugin.reset()

  for cmd in commands:
    case cmd.kind:
      of pushScene:
        app.push(cmd.pushId)
      of popScene:
        discard app.pop()
      of gotoScene:
        app.goto(cmd.gotoId)

proc beginFrame* (app: Application) =
  SDL_SetRenderDrawColorFloat(app.renderer, 0.0, 0.0, 0.0, 1.0)
  SDL_RenderClear(app.renderer)

proc endFrame* (app: Application) =
  app.artist.render()
  SDL_RenderPresent(app.renderer)

proc render* (app: Application) {.raises: [Exception].} =
  app.beginFrame()
  for plugin in app.plugins.plugins:
    if plugin.isScene and plugin.id != app.currentScene():
      continue
    plugin.render(app.artist)
  app.endFrame()

proc run* (app: var Application) {.raises: [Exception].} =
  app.load()
  while app.running():
    app.update()
    app.render()
