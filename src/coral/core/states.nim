import json, jsony, tables, options, typetraits, fusion/matching

{.experimental: "caseStmtMacros".}

type
  JsonString = string
  GameState* = object
    version = 1
    state: Table[string, JsonString]
    currentScene*: Option[string]

type AbstractGameState = ref object of RootObj
type GenericGameState[T] = ref object of AbstractGameState
  state: T

var shouldSerialize = false
var states = initTable[string, AbstractGameState]()

proc getState*[T](st: GameState, t: typedesc[T]): T =
  if not states.hasKey(name(t)) and st.state.hasKey(name(t)):
    states[name(t)] = GenericGameState[T](state: st.state[name(t)].fromJson(
        T)).AbstractGameState

  result = cast[GenericGameState[T]](states[name(t)]).state

proc setState*[T](st: var GameState, state: T) =
  # if not st.state.hasKey(name(T)) or shouldSerialize:
  #   st.state[name(T)] = state.toJson()

  states[name(T)] = GenericGameState[T](state: state).AbstractGameState

template withState*[T](st: GameState, t: typedesc[T], blk: untyped) =
  blk(getState[T](st, t))

template withState*[T](st: GameState, t: typedesc[T], v: untyped,
    blk: untyped) =
  blk(getState[T](st, t), v)

template withState*[T](st: var GameState, t: typedesc[T], blk: untyped) =
  var nst = getState[T](st, t)
  blk(nst)
  setState[T](st, nst)

template withState*[T](st: var GameState, t: typedesc[T], v: untyped,
    blk: untyped) =
  var nst = getState[T](st, t)
  blk(nst, v)
  setState[T](st, nst)

proc init*(T: type GameState, scene = none(string)): T =
  result.currentScene = scene

proc serialize*(gs: GameState) =
  shouldSerialize = true

proc update*() =
  shouldSerialize = false

proc isSceneActive*(self: GameState, sc: string): bool =
  if Some(@id) ?= self.currentScene:
    result = sc == id

proc activeScene*(self: GameState): Option[string] =
  self.currentScene
