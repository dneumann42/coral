import patty, sets, typetraits, sequtils, options
import std/logging

type SceneId* = string

variantp SceneChange:
  Go(pushId: SceneId)
  Change(changeId: SceneId)
  Back

type Scenes* = object
  sceneStack: seq[SceneId]
  loadSet: HashSet[string]

proc sceneId*[T](sc: T): SceneId =
  name type(sc)

proc init*(T: type Scenes): T =
  T(sceneStack: @[], loadSet: initHashSet[string]())

proc activeScene*(self: var Scenes): Option[string] =
  if self.sceneStack.len() > 0:
    result = self.sceneStack[^1].some

proc shouldLoad*(self: var Scenes): seq[SceneId] =
  result = self.loadSet.toSeq()
  self.loadSet.clear()

proc add*(self: var Scenes, id: SceneId) =
  self.sceneStack.add(id)
  self.loadSet.incl(id)

proc pop*(self: var Scenes): Option[SceneId] =
  if len(self.sceneStack) > 0:
    result = self.sceneStack.pop().some

proc change*(self: var Scenes, ch: SceneChange): Option[
    SceneId] {.discardable.} =
  info("Changing scene: " & $ch)
  match ch:
    Go(pushId):
      self.loadSet.incl(pushId)
      self.add(pushId)
    Back:
      result = self.pop()
    Change(changeId):
      result = self.pop()
      self.loadSet.incl(changeId)
      self.sceneStack.add(changeId)

