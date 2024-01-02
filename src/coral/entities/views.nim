import ../core/[typeids, saving]
import std/[sets, sequtils]

import types

type
  ViewKey = HashSet[TypeId]

type
  View* = ref object
    valid*: bool
    key: ViewKey
    entities: seq[EntId]

proc new*(T: type View; key: HashSet[TypeId]): T = T(key: key, entities: @[])
proc new*(T: type View; key: varargs[TypeId]): T = T.new(key.toSeq.toHashSet)
proc new*(T: type View; key: UncheckedArray[TypeId]): T = T.new(key.toHashSet)

proc keyMatch*(view: View; key: openArray[TypeId]): bool =
  result = true
  for k in key:
    if not view.key.contains(k):
      return false

proc clear*(view: View) =
  view.entities.setLen(0)

proc contains*(view: View; entId: EntId): bool =
  view.entities.contains(entId)

iterator entities*(view: View): EntId =
  for ent in view.entities:
    yield ent

iterator items*(view: View): EntId =
  for ent in view.entities:
    yield ent

proc add*(v: View; entId: EntId) =
  if not v.contains(entId):
    v.entities.add(entId)

proc len*(view: View): int =
  view.entities.len

proc version*(T: type View): int = 1
proc save*(e: View): JsonNode = %* {}
proc `%`*(e: View): JsonNode = e.save()
proc migrate*(T: type View; js: JsonNode): JsonNode = js
proc load*(T: type View; n: JsonNode): T = to(T.migrate(n), T)

static:
  assert View is Savable
  assert View is Loadable
