# Goal, render a texture that can be transformed, skewed and sheared, scaled and translated

import opengl
import ngl

const RectangleVertices = [
  GLfloat(1.0),
  1.0,
  0.0, # top right
  1.0,
  -1.0,
  0.0, # bottom right
  -1.0,
  -1.0,
  0.0, # bottom left
  -1.0,
  1.0,
  0.0, # top left
]

const RectangleIndices = [GLuint(0), 1, 3, 1, 2, 3]

var rectVao: VertexArray
var rectVbo: VertexBuffer
var rectEbo: VertexBuffer

proc initialize*() =
  rectVao = VertexArray.init()
  rectVbo = VertexBuffer.init()
  rectEbo = VertexBuffer.init(GL_ELEMENT_ARRAY_BUFFER)
