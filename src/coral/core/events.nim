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

var events = Events.init()

proc isKind*(ev: SomeEvent, t: typedesc): bool =
  ev.id == name(t)

template whenEvent*(ev: SomeEvent, t: typedesc, blk: untyped) =
  if ev.isKind(t):
    ev.persist = false
    let event {.inject.} = ev.get(t)
    blk
  # a.kind == CircleKind and (let myOtherVar = Circle(a); true)

proc get*(ev: SomeEvent, t: typedesc): t =
  ((Event[t])(ev)).state

proc emit*[T](state: T) =
  events.queue.add(Event[T](state: state, id: name(T), persist: true).SomeEvent)

proc flushEvents*() =
  events.stack = events.stack.filterIt(it.persist)

iterator pollEvents*(): var SomeEvent =
  for item in events.queue:
    events.stack.add(item)
  events.queue.setLen(0)

  for ev in events.stack.mitems:
    yield ev

proc isEventActive*(t: typedesc): bool =
  for ev in events.stack:
    if ev.isKind(t):
      return true

