## For now the only supported format is Json, I would like to extend that
## to xml, yaml and s-expressions. Potentially toml and maybe protobuf

import std/[json, macros]

export json

type
  Migratable* {.explain.} = concept type T
    T.migrate(JsonNode) is JsonNode

  Savable* {.explain.} = concept x, type T
    T is Migratable
    x.`%`() is JsonNode
    T.version is int

  Loadable* {.explain.} = concept type T
    T is Savable
    T.load(JsonNode) is T

  SavableLoadable* = concept type T
    T is Savable
    T is Loadable

macro implSavableVersioned*(t: typedesc, vers = 1): untyped =
  proc toJson[T](ty: T): JsonNode = %* ty
  let saveId = ident("`%`")
  quote do:
    proc version*(T: type `t`): int = `vers`
    proc `saveId`*(s: `t`): JsonNode = toJson(s)

macro implMigratable*(t: typedesc, vers = 1): untyped =
  proc toJson[T](ty: T): JsonNode = %* ty
  let saveId = ident("`%`")
  quote do:
    proc migrate*(T: type `t`, js: JsonNode): JsonNode = js

template implSavable*(t: typedesc, vers = 1): auto =
  implSavableVersioned(t, vers)
  implMigratable(t, vers)

macro implLoadable*(t: typedesc): untyped =
  quote do:
    proc load*(T: type `t`, n: JsonNode): `t` =
      to(n, `t`)

template implSaveLoad*(t: typedesc, version: int) =
  implSavable(t, version)
  implLoadable(t)
