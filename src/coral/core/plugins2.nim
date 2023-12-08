import tools, hashes, rdstdin

import std/[macros, macrocache]

type
  AbstractPlugin = ref object of RootObj
  Plugin = ref object of AbstractPlugin

type PluginFunc = proc(): void

type PluginId = distinct string

proc `$`*(id: PluginId): string {.borrow.}
proc hash*(id: PluginId): Hash {.borrow.}

const functions = CacheTable"functions"

# var functionValues: seq[]

# macro add*[S: enum](pluginId: PluginId, step: S, fun: untyped) =
#   functions.add((pluginId, step, fun))

macro generatePluginSteps*[S: enum]() =
  # Idea:
  # we generate the step function

  # Generate a function for each step, parameterized by `S`
  # each step will call doStep and in turn that will call all
  # of the plugins subscribed to the step passed to doStep

  # the user of this api will have to call the step functions manually

  discard

proc step*[S: enum](s: S) =
  discard
  # quote do:
  #   for

when isMainModule:
  proc load() =
    discard

  type
    Steps = enum
      load
      update
      draw
      unload

  "Hello".PluginId.add(load)

  generatePluginSteps[Steps]()

  var line: string
  while true:
    let ok = readLineFromStdin("> ", line)
    if not ok:
      break
    echo(line)
