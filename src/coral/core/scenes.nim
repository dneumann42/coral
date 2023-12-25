import sets, typetraits, sequtils, options
import std/logging

type SceneId* = string

var allScenes: HashSet[string]
var sceneStack: seq[SceneId]
var loadSet: HashSet[string]

proc sceneId*[T](sc: T): SceneId =
  name(type(sc))

proc activeScene*(): Option[string] =
  if sceneStack.len() > 0:
    result = sceneStack[^1].some

proc shouldLoad*(id: SceneId, keep = false): bool =
  result = loadSet.contains(id)
  if result and not keep:
    loadSet.excl(id)

proc canLoadScene*(id: SceneId): bool =
  result = loadSet.contains(id)

proc registerScene*(id: SceneId) =
  allScenes.incl(id)

proc isScene*(id: SceneId): bool =
  allScenes.contains(id)

proc pushScene*(id: SceneId) =
  sceneStack.add(id)
  loadSet.incl(id)

proc popScene*(): Option[SceneId] =
  if len(sceneStack) > 0:
    result = sceneStack.pop().some

proc backScene*(): Option[SceneId] =
  result = popScene()

proc changeScene*(sceneId: SceneId): Option[SceneId] =
  result = popScene()
  pushScene(sceneId)
