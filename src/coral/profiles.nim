import std / [ times, json, os, sugar, sequtils ]
import sdl3

type
  Profile* = object
    organization*, appName*: string
    name*: string
    version* = 0 
    lastSaved*: DateTime

proc init* (T: type Profile, name: string): T =
  T(name: name, version: 1)

proc profilesDirectory* (org, name: string): string =
  var str = SDL_GetPrefPath(org.cstring, name.cstring)
  defer: SDL_Free(str)
  result = $str

proc profileDirectory* (profile: Profile): string =
  profilesDirectory(profile.organization, profile.appName) / profile.name

proc createProfileDirectory(profile: Profile) =
  let profileDir = profile.profileDirectory()
  var pathInfo: SDL_PathInfo
  if not SDL_GetPathInfo(profileDir.cstring, pathInfo):
    discard SDL_CreateDirectory(profileDir.cstring)

proc pathExists* (path: string): bool =
  var pathInfo: SDL_PathInfo
  result = SDL_GetPathInfo(path.cstring, pathInfo)

proc readProfileData* (profile: var Profile): string =
  let dataPath = profile.profileDirectory() / "data.json"
  if pathExists(dataPath):
    result = readFile(dataPath)

proc readProfile* (name: string, profile: var Profile) =
  profile.name = name
  profile.createProfileDirectory()
  let profileData = readFile(profile.profileDirectory() / "profile.json").parseJson()
  profile.name = profileData["name"].to(string)
  profile.version = profileData["version"].to(int)
  let lastSavedStr = profileData["lastSaved"].to(string)
  profile.lastSaved = parse(lastSavedStr, "yyyy-MM-dd'T'HH:mm:sszzz", utc())

proc readProfile* (profile: var Profile): string =
  readProfile(profile.name, profile)
  result = profile.readProfileData()

proc writeProfile* (profile: Profile, data: string) =
  profile.createProfileDirectory()
  let profileData = %* { 
    "name": % profile.name, 
    "version": % profile.version,
    "lastSaved": % ( $now())
  }
  let d = profile.profileDirectory()
  writeFile(d / "profile.json", profileData.pretty)
  writeFile(d / "data.json", data)

iterator profiles* (org, name: string): Profile =
  for f in walkDir(profilesDirectory(org, name)):
    var p = Profile(organization: org, appName: name)
    readProfile(f.path.extractFilename(), p)
    yield p

proc allProfiles* (org, name: string): seq[Profile] =
  result = profiles(org, name).toSeq()

when isMainModule:
  echo allProfiles("SkyVault", "Owl Tower")
