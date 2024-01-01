import patty, json, typetraits

import saving

variantp Command:
  PushScene(pushId: string)
  ChangeScene(changeId: string)
  BackScene
  SaveProfile
  NewProfile(newId: string)
  LoadProfile(loadId: string)
  DeleteProfile(deleteId: string)
  Exit

type
  Commands* = object
    stack: seq[Command]

proc version*(commands: type Commands): int = 1

proc `%`*(c: Command): JsonNode =
  match c:
    PushScene(pushId):
      result = %* {"kind": "PushScene", "pushId": pushId}
    ChangeScene(changeId):
      result = %* {"kind": "ChangeScene", "changeId": changeId}
    BackScene:
      result = %* {"kind": "BackScene"}
    SaveProfile:
      result = %* {"kind": "SaveProfile"}
    NewProfile(newId):
      result = %* {"kind": "NewProfile", "newId": newId}
    LoadProfile(loadId):
      result = %* {"kind": "LoadProfile", "loadId": loadId}
    DeleteProfile(deleteId):
      result = %* {"kind": "DeleteProfile", "deleteId": deleteId}
    Exit:
      result = %* {"kind": "Exit"}

proc `%`*(cs: seq[Command]): JsonNode =
  result = %* []
  for c in cs:
    result.add( % c)

proc `%`*(c: Commands): JsonNode =
  result = %* {"stack": c.stack}

proc save*(c: Commands): JsonNode =
  result = % c

proc load*(T: type Commands, n: JsonNode): T = to(T.migrate(n), T)
proc migrate*(T: type Commands, js: JsonNode): JsonNode = js

iterator items*(commands: Commands): Command =
  for c in commands.stack:
    yield c

proc init*(T: type Commands): T =
  T(stack: @[])

proc clear*(self: var Commands) =
  self.stack.setLen(0)

proc pushScene*(self: var Commands, id: string) =
  self.stack.add(PushScene(id))

proc backScene*(self: var Commands) =
  self.stack.add(BackScene())

proc changeScene*(self: var Commands, id: string) =
  self.stack.add(ChangeScene(id))

proc newProfile*(self: var Commands, id: string) =
  self.stack.add(NewProfile(id))

proc saveProfile*(self: var Commands) =
  self.stack.add SaveProfile()

proc loadProfile*(self: var Commands, id: string) =
  self.stack.add LoadProfile(id)

proc deleteProfile*(self: var Commands, id: string) =
  self.stack.add DeleteProfile(id)

proc exit*(self: var Commands): var Commands {.discardable.} =
  self.stack.add Exit()
  self

static:
  assert Commands is Savable
  assert Commands is Loadable

when isMainModule:
  echo Commands.init().save()
