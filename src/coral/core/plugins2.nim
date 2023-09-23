import std/logging, strutils, sequtils, tables
import sugar, events, tables, patty, options, commands, states, ents
import ../artist/artist

import std/macros
import std/macrocache

import fusion/matching
{.experimental: "caseStmtMacros".}


type Plugins = object

macro plugin(name: string, blk: untyped) =
  discard

when isMainModule:
  proc update() =
    discard
  
  var plugs = Plugins()

  expandMacros:
    add(plugs, update)
