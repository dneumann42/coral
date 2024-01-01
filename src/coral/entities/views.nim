import ../core/[typeids]
import types

type
  View* = ref object
    valid*: bool
    keys: seq[TypeId]
    entities: seq[EntId]

proc new*(T: type View; keys = newSeq[TypeId]()): T = T(keys: keys, entities: @[])
proc new*(T: type View; keys: varargs[TypeId]): T = T.new(@keys)
proc new*(T: type View; keys: UncheckedArray[TypeId]): T = T.new(@keys)

func hasKey*(view: View; key: TypeId): bool =
  result = view.keys.contains(key)

iterator keys*(view: View): TypeId =
  for k in view.keys:
    yield k

proc keyMatch*(view: View; keys: openArray[TypeId]): bool =
  if view.keys.len != keys.len:
    return false
  result = true
  for k in keys:
    if not view.hasKey(k):
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
