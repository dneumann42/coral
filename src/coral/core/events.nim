import options, json, typetraits, sequtils

type
  EventId = string
  SomeEvent* = ref object of RootObj
    id*: EventId

  Event*[T] = ref object of SomeEvent
    state*: T

  Events* = object
    stack: seq[SomeEvent]

func init*(T: type Events): T =
  T(stack: @[])

proc isKind*(ev: SomeEvent, t: typedesc): bool =
  ev.id == name(t)

proc get*(ev: SomeEvent, t: typedesc): t =
  ((Event[t])(ev)).state

proc emit*[T](events: var Events, state: T) =
  events.stack.add(Event[T](state: state, id: name(T)).SomeEvent)

proc flush*(events: var Events) =
  events.stack.setLen(0)

iterator poll*(events: var Events): SomeEvent =
  var evs = events.stack.toSeq()
  for ev in evs:
    yield ev

proc isEventActive*(events: var Events, t: typedesc): bool =
  for ev in events.stack:
    if ev.isKind(t):
      return true

