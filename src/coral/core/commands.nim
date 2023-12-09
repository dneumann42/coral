import patty, json, typetraits
import scenes, events

variantp Command:
  PushScene(pushId: string)
  ChangeScene(changeId: string)
  BackScene
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
  self.stack.add(PushScene(id))
  self

proc backScene*(self: var Commands) =
  self.stack.add(BackScene())

proc changeScene*(self: var Commands, id: string): var Commands {.discardable.} =
  self.stack.add(ChangeScene(id))
  self

proc saveProfile*(self: var Commands): var Commands {.discardable.} =
  self.stack.add SaveProfile()
  self

proc exit*(self: var Commands): var Commands {.discardable.} =
  self.stack.add Exit()
  self
