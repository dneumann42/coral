import options, json, typetraits, sequtils

type
  EventId = string
  SomeEvent* = ref object of RootObj
    id*: EventId
    persist* = false

  Event*[T] = ref object of SomeEvent
    state*: T

  Events* = object
    queue: seq[SomeEvent]
    stack: seq[SomeEvent]

func init*(T: type Events): T =
  T(stack: @[], queue: @[])

proc isKind*(ev: SomeEvent, t: typedesc): bool =
  ev.id == name(t)

proc get*(ev: SomeEvent, t: typedesc): t =
  ((Event[t])(ev)).state

proc emit*[T](events: var Events, state: T) =
  events.queue.add(Event[T](state: state, id: name(T)).SomeEvent)

proc emitPersist*[T](events: var Events, state: T) =
  events.queue.add(Event[T](state: state, id: name(T), persist: true).SomeEvent)

proc flush*(events: var Events) =
  events.stack = events.stack.filterIt(it.persist)

iterator poll*(events: var Events): var SomeEvent =
  for item in events.queue:
    events.stack.add(item)
  events.queue.setLen(0)

  for ev in events.stack.mitems:
    yield ev

proc isEventActive*(events: var Events, t: typedesc): bool =
  for ev in events.stack:
    if ev.isKind(t):
      return true

