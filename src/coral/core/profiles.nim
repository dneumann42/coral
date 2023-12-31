import std/json, os, tables, typetraits, macros, typetraits

import ../platform/application

type
  Profile* = object
    version*: int = 1
    gameName*: string
    name*: string
    # TODO: lastWritten: DateTime

  Savable*{.explain.} = concept x, type T
    x.save() is JsonNode
    T.version is int
    T.migrate(JsonNode) is JsonNode

  Loadable* {.explain.} = concept type T
    T is Savable
    T.load(JsonNode) is T

proc getProfilesDir*(gameName: string): string =
  (getSaveDirectoryPath(gameName, "").string)[0..^2] / "profiles"

proc requiresMigration*(n: JsonNode, targetVersion: int): bool =
  if not n.hasKey("version"):
    return false
  n["version"].getInt() != targetVersion

proc save*(profile: Profile) =
  try:
    let saveDir = getProfilesDir(profile.gameName)
    if not dirExists(saveDir / profile.name):
      createDir(saveDir / profile.name)
    writeFile(saveDir / profile.name / "profile.json", ( %* profile).pretty)
  except IOError:
    echo getCurrentExceptionMsg()

proc save*(profile: Profile, name: string, state: Savable) =
  let saveDir = getProfilesDir(profile.gameName) / profile.name
  let statesDir = saveDir / "states"

  try:
    if not dirExists(statesDir):
      createDir(statesDir)
    var js = state.save()
    js["version"] = % typeof(state).version
    writeFile(statesDir / (name & ".json"), js.pretty)
  except CatchableError:
    echo getCurrentExceptionMsg()

proc load*(profile: var Profile, migrate: proc(name: string,
    js: JsonNode): JsonNode): Table[string, JsonNode] =
  let saveDir = getProfilesDir(profile.gameName) / profile.name
  let statesDir = saveDir / "states"

  try:
    if not dirExists(saveDir):
      return initTable[string, JsonNode]()
    let loadedProfile = to(parseJson(readFile(saveDir / "profile.json")), Profile)
    profile.name = loadedProfile.name
    profile.gameName = loadedProfile.gameName

    for (kind, path) in walkDir(statesDir, relative = true):
      if kind != pcFile:
        continue
      let name = path[0..<searchExtPos(path)].extractFilename()
      var stateJson = parseJson(readFile(statesDir / path))
      result[name] = migrate(name, stateJson)
  except CatchableError:
    echo getCurrentExceptionMsg()

proc getProfiles*(gameName: string): seq[Profile] =
  let profileDir = getProfilesDir(gameName)
  for (kind, path) in walkDir(profileDir, relative = true):
    if kind == pcFile:
      continue
    result.add(to(parseJson(readFile(profileDir / path / "profile.json")), Profile))

macro genMigrationFun*(jsName: string, js: JsonNode,
    savables: untyped): untyped =
  result = nnkStmtList.newTree()

  for savable in savables:
    let check = quote do:
      if name(`savable`) == `jsName` and requiresMigration(`js`,
          `savable`.version):
        return `savable`.migrate(js)
    result.add(check)

  result.add(quote do: return `js`)

macro saveProfile*(profile: Profile, states: untyped): untyped =
  var saves = nnkStmtList.newTree()
  for state in states:
    let val = state[0]
    let id = state[1]
    saves.add(quote do: `profile`.save(name(`id`), `val`))
  quote do:
    `profile`.save()
    `saves`

macro implSavable*(t: typedesc, vers = 1): untyped =
  proc toJson[T](ty: T): JsonNode = %* ty
  quote do:
    proc version*(T: type `t`): int = `vers`
    proc save*(s: `t`): JsonNode = toJson(s)
    proc load*(T: type `t`, n: JsonNode, version: int): T = to(n, T)
    proc migrate*(T: type `t`, js: JsonNode): JsonNode = js

macro implSavable*(t: typedesc, vers: int, migrate: untyped): untyped =
  quote do:
    proc version*(T: type `t`): int = `vers`
    proc save*(s: `t`): JsonNode = %* s
    proc load*(T: type `t`, n: JsonNode, version: int): T = to(n, T)
    proc migrate*(T: type `t`, js: JsonNode): JsonNode = `migrate`(js)

when isMainModule:
  var prof = Profile(name: "test", gameName: "TestGame")
  echo getProfilesDir("TestGame")

  echo getProfiles("TestGame")
  saveProfile(prof, [])

  # type SaveState* = object
  #   magic = 420
  # type SaveState2* = object
  #   other = 113

  # var s = SaveState()
  # var s2 = SaveState2()

  # implSavable(SaveState)
  # implSavable(SaveState2)

  # expandMacros:

  # var states = prof.load() do (jsName: string, js: JsonNode) -> JsonNode:
  #   expandMacros:
  #     genMigrationFun(jsName, js, [SaveState, SaveState2])

  # var state = SaveState.load(states[name(SaveState)], SaveState.version)
  # var state2 = SaveState2.load(states[name(SaveState2)], SaveState2.version)
  # echo state, " ", state2
