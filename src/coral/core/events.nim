import options, json, typetraits

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
  for ev in events.stack:
    yield ev
