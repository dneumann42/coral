import opengl
import std/logging

type Bindable* =
  concept t
      t.start() is void
      t.stop() is void

## VAO
type VertexArray* = object
  id: GLuint

template with*(b: Bindable, blk: untyped) =
  b.start()
  blk
  b.stop()

proc init*(T: type VertexArray): T =
  result = T(id: 0.GLuint)
  glGenVertexArrays(1, result.id.addr)

proc start*(v: VertexArray) =
  glBindVertexArray(v.id)

proc stop*(v: VertexArray) =
  glBindVertexArray(0.GLuint)

proc `=sink`(x: var VertexArray, y: VertexArray) {.error.}
proc `=copy`(x: var VertexArray, y: VertexArray) {.error.}
proc `=wasMoved`(x: var VertexArray) {.error.}
proc `=destroy`(v: VertexArray) =
  try:
    glDeleteVertexArrays(1, v.id.addr)
  except GLerror:
    error(getCurrentExceptionMsg())

## VBO
type VertexBuffer* = object
  kind: GLenum = GL_ARRAY_BUFFER
  id: GLuint

proc init*(T: type VertexBuffer, kind = GL_ARRAY_BUFFER): T =
  result = T(id: 0.GLuint, kind: kind)
  glGenBuffers(1, result.id.addr)

proc start*(v: VertexBuffer) =
  glBindBuffer(v.kind, v.id)

proc stop*(v: VertexBuffer) =
  glBindBuffer(v.kind, 0.GLuint)

proc `=sink`(x: var VertexBuffer, y: VertexBuffer) {.error.}
proc `=copy`(x: var VertexBuffer, y: VertexBuffer) {.error.}
proc `=wasMoved`(x: var VertexBuffer) {.error.}
proc `=destroy`(v: VertexBuffer) =
  try:
    glDeleteBuffers(1, v.id.addr)
  except GLerror:
    error(getCurrentExceptionMsg())
