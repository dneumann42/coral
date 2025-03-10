import std / [ options, tables ]

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

var input = Input(
  actions: initTable[ActionId, Binding]()
)

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

proc addAction* (id: string, key: Keycode) =
  input.actions[id] = Binding(key: key.some(), now: false, last: false)

proc updateActions* () =
  for act in input.actions.mvalues:
    act.last = act.now

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
