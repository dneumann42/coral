import options, json

type
  EventId = string

  Event* = object
    id: EventId
    state: Option[JsonNode]

  Events* = object
    events: seq[Event]

func init*(T: type Events): T =
  T(events: @[])

func init*(T: type Event, id: EventId, state = none(JsonNode)): T =
  T(id: id, state: state)
