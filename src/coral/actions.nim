import std / [ options, tables ]

import sdl3

import keys
export keys

type
  ActionState* = object
    pressed*, down*, released*, up*: bool

  Binding* = object
    key: Option[Keycode]
    now, last: bool

  ActionId* = string

  Input* = object
    actions: Table[ActionId, Binding]
    mouseLeft, mouseRight: Binding

  RepeatAction* = object
    timeout = 0.3
    timer = 0.0

var input = Input(
  actions: initTable[ActionId, Binding]()
)

proc init* (T: type RepeatAction, timeout = 0.3): T =
  T(timeout: timeout, timer: 0.0) 

proc isActive* (action: var RepeatAction, state: ActionState, delta: float): bool =
  if state.pressed:
    action.timer = action.timeout
    result = true
  if action.timer > 0.0:
    action.timer -= delta
  if action.timer <= 0.0 and state.down:
    action.timer = action.timeout
    result = true

proc action* (id: string): ActionState =
  if not input.actions.hasKey(id):
    return
  
  let action = input.actions[id]
  result = ActionState(
    pressed: action.now and not action.last,
    released: not action.now and action.last,
    down: action.now,
    up: not action.now
  )
  
proc mouseLeft* (): ActionState =
  result = ActionState(
    pressed: input.mouseLeft.now and not input.mouseLeft.last,
    released: not input.mouseLeft.now and input.mouseLeft.last,
    down: input.mouseLeft.now,
    up: not input.mouseLeft.now
  )

proc mousePosition* (scaleX = 1.0, scaleY = 1.0): tuple[x, y: float] =
  var x, y: cfloat
  discard SDL_GetMouseState(x, y)
  result = (x / scaleX, y / scaleY)

proc addAction* (id: string, key: Keycode) =
  input.actions[id] = Binding(key: key.some(), now: false, last: false)

proc updateActions* () =
  for act in input.actions.mvalues:
    act.last = act.now
  input.mouseLeft.last = input.mouseLeft.now
  input.mouseRight.last = input.mouseRight.now

proc handleKeyPressed* (key: Keycode) =
  for act in input.actions.mvalues:
    if act.key.isNone or act.key.get != key:
      continue
    act.now = true

proc handleKeyReleased* (key: Keycode) =
  for act in input.actions.mvalues:
    if act.key.isNone or act.key.get != key:
      continue
    act.now = false

proc handleMousePressed* (button: uint8) =
  if button == 1:
    input.mouseLeft.now = true

proc handleMouseReleased* (button: uint8) =
  if button == 1:
    input.mouseLeft.now = false
