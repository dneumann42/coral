import options, json, typetraits

type
  EventId = string
  AbstractEvent* = ref object of RootObj
    id*: EventId

  Event*[T] = ref object of AbstractEvent
    state*: T

  Events* = object
    stack: seq[AbstractEvent]

func init*(T: type Events): T =
  T(stack: @[])

proc isKind*(ev: AbstractEvent, t: typedesc): bool =
  ev.id == name(t)

proc get*(ev: AbstractEvent, t: typedesc): t =
  ((Event[t])(ev)).state

proc emit*[T](events: var Events, state: T) =
  events.stack.add(Event[T](state: state, id: name(T)).AbstractEvent)

proc flush*(events: var Events) =
  events.stack.setLen(0)

iterator poll*(events: var Events): AbstractEvent =
  for ev in events.stack:
    yield ev
