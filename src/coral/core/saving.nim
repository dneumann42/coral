## For now the only supported format is Json, I would like to extend that
## to xml, yaml and s-expressions. Potentially toml and maybe protobuf

import std/[json, macros]

export json

type
  Savable* {.explain.} = concept x, type T
    x.save() is JsonNode
    T.version is int
    T.migrate(JsonNode) is JsonNode

  Loadable* {.explain.} = concept type T
    T is Savable
    T.load(JsonNode) is T

macro implSavable*(t: typedesc, vers = 1): untyped =
  proc toJson[T](ty: T): JsonNode = %* ty
  quote do:
    proc version*(T: type `t`): int = `vers`
    proc save*(s: `t`): JsonNode = toJson(s)
    proc load*(T: type `t`, n: JsonNode, version: int): T = to(T.migrate(n), T)
    proc migrate*(T: type `t`, js: JsonNode): JsonNode = js
