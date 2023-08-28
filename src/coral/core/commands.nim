import patty, json, typetraits
import scenes, events

variantp Command:
  Scene(change: SceneChange)
  Emit(event: Event)
  SaveProfile
  Exit

type
  Commands* = object
    stack: seq[Command]

iterator items*(commands: Commands): Command =
  for c in commands.stack:
    yield c

proc init*(T: type Commands): T =
  T(stack: @[])

proc pushScene*(self: var Commands, id: string): var Commands {.discardable.} =
  self.stack.add Scene(Go(id))
  self

proc popScene*(self: var Commands) =
  self.stack.add Scene(Back())

proc changeScene*(self: var Commands, id: string): var Commands {.discardable.} =
  self.stack.add Scene(Change(id))
  self

proc saveProfile*(self: var Commands): var Commands {.discardable.} =
  self.stack.add SaveProfile()
  self

proc exit*(self: var Commands): var Commands {.discardable.} =
  self.stack.add Exit()
  self

proc emit*[T](self: var Commands, state: T): var Commands {.discardable.} =
  self.stack.add Event(Event.init(name(typedesc(T)), %* state))
  self
