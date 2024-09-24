import json, typetraits

import saving

type
  CommandKind* = enum
    pushScene
    changeScene
    backScene
    saveProfile
    newProfile
    loadProfile
    deleteProfile
    pauseGame
    resumeGame
    exit

  Command = object
    case kind*: CommandKind
      of pushScene:
        pushId*: string
      of changeScene:
        changeId*: string
      of newProfile:
        newId*: string
      of loadProfile:
        loadId*: string
      of deleteProfile:
        deleteId*: string
      else:
        discard

type
  Commands* = object
    stack: seq[Command]

proc version*(commands: type Commands): int = 1

proc `%`*(c: Command): JsonNode =
  case c.kind:
    of pushScene:
      %* {"kind": "PushScene", "pushId": c.pushId}
    of changeScene:
      %* {"kind": "ChangeScene", "changeId": c.changeId}
    of backScene:
      %* {"kind": "BackScene"}
    of saveProfile:
      %* {"kind": "SaveProfile"}
    of newProfile:
      %* {"kind": "NewProfile", "newId": c.newId}
    of loadProfile:
      %* {"kind": "LoadProfile", "loadId": c.loadId}
    of deleteProfile:
      %* {"kind": "DeleteProfile", "deleteId": c.deleteId}
    of pauseGame:
      %* {"kind": "PauseGame"}
    of resumeGame:
      %* {"kind": "ResumeGame"}
    of exit:
      %* {"kind": "Exit"}

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
  self.stack.add(Command(kind: pushScene, pushId: id))

proc pause*(self: var Commands) =
  self.stack.add(Command(kind: pauseGame))

proc resume*(self: var Commands) =
  self.stack.add(Command(kind: resumeGame))

proc backScene*(self: var Commands) =
  self.stack.add(Command(kind: backScene))

proc changeScene*(self: var Commands, id: string) =
  self.stack.add(Command(kind: changeScene, changeId: id))

proc newProfile*(self: var Commands, id: string) =
  self.stack.add(Command(kind: newProfile, newId: id))

proc saveProfile*(self: var Commands) =
  self.stack.add(Command(kind: saveProfile))

proc loadProfile*(self: var Commands, id: string) =
  self.stack.add(Command(kind: loadProfile, loadId: id))

proc deleteProfile*(self: var Commands, id: string) =
  self.stack.add(Command(kind: deleteProfile, deleteId: id))

proc exit*(self: var Commands): var Commands {.discardable.} =
  self.stack.add(Command(kind: exit))
  self

static:
  assert Commands is Savable
  assert Commands is Loadable

when isMainModule:
  echo Commands.init().save()
