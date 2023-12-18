import tables, options, vmath

import ../platform/keys
import ../platform/application

type
  Binding* = object
    key: Option[KeyboardKey]
    # btn: Option[GamepadButton]
    # mouse: Option[MouseButton]

proc init*(T: type Binding, key = none(KeyboardKey)): T =
  result.key = key

var actions = {
  "action": Binding.init(some space),
}.toTable

proc down*(b: Binding): bool =
  result = b.key.map(isDown).get(false)

proc pressed*(b: Binding): bool =
  result = b.key.map(isPressed).get(false)

proc up*(b: Binding): bool =
  result = b.key.map(isUp).get(false)

proc release*(b: Binding): bool =
  result = b.key.map(isReleased).get(false)

proc down*(key: KeyboardKey): bool =
  result = key.isDown()

proc pressed*(key: KeyboardKey): bool =
  result = key.isPressed()

proc up*(key: KeyboardKey): bool =
  result = key.isUp()

proc released*(key: KeyboardKey): bool =
  result = key.isReleased()

proc down*(mb: MouseButton): bool =
  result = mb.isDown()

proc up*(mb: MouseButton): bool =
  result = mb.isUp()

proc pressed*(mb: MouseButton): bool =
  result = mb.isPressed()

proc released*(mb: MouseButton): bool =
  result = mb.isReleased()

proc input*(id: string): Binding =
  actions[id]

proc mousePosition*(): Vec2 =
  application.mousePosition()
