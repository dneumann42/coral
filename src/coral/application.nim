import std / [ options, sequtils, logging, macros, algorithm, sugar ]

import sdl3

import prelude, plugins, drawing, actions, resources, appcommands, clock
export prelude, plugins, drawing, actions, resources, clock

type
  ApplicationConfig* = object
    organization* = "Coral Game"
    name* = "Coral"
    width* = 640 * 2
    height* = 480 * 2
    title* = "Coral"

  ApplicationMeta* = object
    organization* = "Coral Game"
    name* = "Coral"

  Application* = object
    meta*: ApplicationMeta

    renderer: SDL_Renderer
    window: SDL_Window
    running: bool = true
    sceneStack: seq[string]
    loadScenes: seq[string]
    plugins*: Plugins
    artist*: Artist
    resources*: Resources

    now: uint64
    last: uint64
    clock: Clock

    frames: seq[float64]

proc `=destroy`(app: Application) =
  SDL_Quit()

proc init* (T: type Application, config = ApplicationConfig.default()): auto {.R(Application, string).} =
  addHandler(newConsoleLogger())

  discard SDL_ScaleMode(SDL_SCALEMODE_NEAREST)

  if not SDL_Init(SDL_INIT_VIDEO):
    return Err($SDL_GetError())

  let window = SDL_CreateWindow(config.title.cstring, config.width, config.height, 0)
  if window.isNil:
    return Err($SDL_GetError())

  let renderer = SDL_CreateRenderer(window, nil)
  if renderer.isNil:
    return Err($SDL_GetError())

  discard SDL_SetRenderVSync(renderer, -1);
  var plugins = Plugins()

  result = Ok(T(
    meta: ApplicationMeta(
      organization: config.organization,
      name: config.name
    ),
    renderer: renderer,
    window: window,
    plugins: plugins,
    sceneStack: @[],
    artist: Artist.init(renderer),
    resources: Resources.init(renderer)
  ))

proc push* (app: var Application, sceneId: string): var Application {.discardable.} =
  app.sceneStack.add(sceneId)
  app.loadScenes.add(sceneId)
  app

proc pop* (app: var Application): Option[string] =
  if app.sceneStack.len() == 0:
    return
  result = app.sceneStack.pop().some()

proc goto* (app: var Application, sceneId: string): var Application {.discardable.} =
  discard app.pop()
  app.push(sceneId)

proc currentScene* (app: Application): string =
  result = app.sceneStack[^1]

proc add* [T: Plugin] (app: var Application, plugin: T): var Application {.discardable.} =
  app.plugins.add(plugin)
  app

proc sortPlugins* (app: var Application) =
  try:
    app.plugins.sortPlugins()
  except:
    echo getCurrentExceptionMsg()

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
      of SDL_EVENT_MOUSE_BUTTON_UP:
        handleMousePressed(event.button.button)
      of SDL_EVENT_MOUSE_BUTTON_DOWN:
        handleMouseReleased(event.button.button)
      else:
        discard

  app.last = app.now
  app.now = SDL_GetPerformanceCounter()

  if app.clock.ticks == 0:
    app.last = app.now

  let diff = max(app.now, app.last) - min(app.now, app.last)
  app.clock.dt = diff.float64 * (1000.0 / SDL_GetPerformanceFrequency().float64) / 1000.0
  app.frames.add(app.clock.dt)
  if app.frames.len >= 15:
    app.clock.avgDt = 0.0
    for dt in app.frames:
      app.clock.avgDt += dt
    app.clock.avgDt /= 15
    app.frames.setLen(0)

  inc app.clock.ticks

  result = app.running

proc load* (app: var Application) {.raises: [Exception].} =
  for plugin in app.plugins.plugins:
    if plugin.isScene:
      continue
    plugin.load()

proc update* (app: var Application) {.raises: [Exception].} =
  defer: updateActions()

  var commands = newSeq[Command]()
  for plugin in app.plugins.mplugins:
    if plugin.isScene and plugin.id != app.currentScene():
      continue

    if app.loadScenes.contains(plugin.id):
      app.loadScenes.del(app.loadScenes.find(plugin.id))
      plugin.load()

    plugin.update(app.clock)
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

proc endFrame* (app: var Application) =
  app.artist.render()
  SDL_RenderPresent(app.renderer)

proc render* (app: var Application) {.raises: [Exception].} =
  app.beginFrame()
  for plugin in app.plugins.plugins:
    if plugin.isScene and plugin.id != app.currentScene():
      continue
    plugin.render(app.artist)
  app.endFrame()

proc run* (app: var Application) {.raises: [Exception].} =
  app.sortPlugins()
  app.load()
  while app.running():
    app.update()

    for plugin in app.plugins.plugins:
      if plugin.isScene and plugin.id != app.currentScene():
        continue
      plugin.preRender(app.artist)

    app.render()
