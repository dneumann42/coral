import json, jsony, tables, options, typetraits, fusion/matching, macros,
    macrocache, std/enumerate
import saving, strutils

const states = CacheSeq"states"
const stateNames = CacheSeq"stateName"
const stateTypes = CacheSeq"stateTypes"
const saves = CacheSeq"saves"

macro registerState*(T: typed): untyped =
  let id = ident(T.repr)
  let varName = ident(id.repr.normalize())
  stateNames.add(varName)
  stateTypes.add(id)
  states.add(
    quote do:
    var `varName` = default(`id`))
  let js = ident("%")
  saves.add(quote do: `js`(`varName`))

macro registerState*(T: typed, name: untyped): untyped =
  let id = ident(T.repr)
  let varName = ident(name.repr.normalize())
  stateNames.add(varName)
  stateTypes.add(id)
  states.add(
    quote do:
    var `varName` = default(`id`))

macro generatePluginJson*(): JsonNode =
  macro arr(js: untyped): untyped =
    var xs = nnkStmtList.newTree()
    for name in stateNames:
      let s = name.repr
      xs.add(quote do:
        `js`.add(`s`, % `name`))
    xs

  quote do:
    block:
      var js {.inject.} = newJObject()
      arr(js)
      js

macro generateStateLoads*(js: untyped): untyped =
  var xs = nnkStmtList.newTree()
  for i, state in enumerate(stateNames):
    let n = newLit($state)
    let ty = stateTypes[i]
    xs.add(quote do: `state` = `ty`.load(`js`[`n`]))
  xs

template generateStateSaves*(): untyped =
  generatePluginJson()

macro generateStates*(): untyped =
  var stmts = nnkStmtList.newTree()
  for state in states:
    stmts.add(state)
  stmts
