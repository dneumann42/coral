import patty, jsony, json, typetraits, macros, sequtils, strutils
import scenes, events

import profiles

variantp Command:
  PushScene(pushId: string)
  ChangeScene(changeId: string)
  BackScene
  SaveProfile
  NewProfile(newId: string)
  LoadProfile(loadId: string)
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

proc load*(T: type Commands, n: JsonNode, version: int): T = to(n, T)
proc migrate*(T: type Commands, js: JsonNode): JsonNode = js

iterator items*(commands: Commands): Command =
  for c in commands.stack:
    yield c

proc init*(T: type Commands): T =
  T(stack: @[])

proc clear*(self: var Commands) =
  self.stack.setLen(0)

proc newProfile*(self: var Commands, id: string): var Commands {.discardable.} =
  self.stack.add(NewProfile(id))
  self

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

when isMainModule:
  echo Commands.init().save()
