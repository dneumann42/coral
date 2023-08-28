import platform, tables, sets, sequtils, options, sugar

type
  Binding* = object
    key: Option[KeyboardKey]
    btn: Option[GamepadButton]
    mouse: Option[MouseButton]

proc init*(T: type Binding, key = none(KeyboardKey), btn = none(GamepadButton),
    mouse = none(MouseButton)): T =
  result.key = key
  result.btn = btn
  result.mouse = mouse

var actions = {
  "action": Binding.init(some KeyboardKey.Space),
}.toTable

proc down*(b: Binding): bool =
  result = b.key.map(isKeyDown).get(false)

proc press*(b: Binding): bool =
  result = b.key.map(isKeyPressed).get(false)

proc up*(b: Binding): bool =
  result = b.key.map(isKeyUp).get(false)

proc release*(b: Binding): bool =
  result = b.key.map(isKeyReleased).get(false)

proc input*(id: string): Binding =
  actions[id]
