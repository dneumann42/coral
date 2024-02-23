# A 2d renderer using sokol gfx

import opengl, sdl2

import sokol/log as slog
import sokol/gfx as sg

var
  pipeline: Pipeline
  bindings: Bindings

proc init*() {.cdecl.} =
  sg.setup(sg.Desc())
