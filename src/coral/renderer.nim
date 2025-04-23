import std / [ options, oids, sets, tables, os ]

import sdl3, bumpy, print
import resources, palette, prelude

#[
  References:
  https://github.com/libsdl-org/SDL/issues/11537
]#

type
  Camera* = object
    x*, y*: float

  Canvas* = ref object
    uid: Oid
    layer: int
    color*: SDL_FColor
    width*, height*: int
    windowWidth*, windowHeight*: int
    texture: SDL_Texture
    shouldRender*: bool
    camera*: Camera

  Renderer* = object
    camera*: Camera
    pipeline: SDL_GPUGraphicsPipeline

const VertexShaderSrc = staticRead("../shaders/basic.vert.glsl")
const FragmentShaderSrc = staticRead("../shaders/basic.frag.glsl")

static:
  echo staticExec("glslangValidator -V ../shaders/basic.vert.glsl -o ../shaders/basic.vert.spv")
  echo staticExec("glslangValidator -V ../shaders/basic.frag.glsl -o ../shaders/basic.frag.spv")

type
  Vec2* = tuple[x, y: float32]

proc init* (T: type Renderer, window: SDL_Window): auto {.R(T, string).} =
  const vertexShaderBin = readFile("src/shaders/basic.vert.spv")
  const fragmentShaderBin = readFile("src/shaders/basic.frag.spv")

  const DebugMode = true
  let device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV.SDL_GPUShaderFormat, DebugMode, nil)
  if device.isNil:
    return Err($SDL_GetError())
  if not SDL_ClaimWindowForGPUDevice(
    device,
    window
  ): return Err($SDL_GetError())

  let presentMode = 
    if SDL_WindowSupportsGPUPresentMode(device, window, SDL_GPU_PRESENTMODE_VSYNC):
      SDL_GPU_PRESENTMODE_VSYNC
    elif SDL_WindowSupportsGPUPresentMode(device, window, SDL_GPU_PRESENTMODE_IMMEDIATE):
      SDL_GPU_PRESENTMODE_IMMEDIATE
    else:
      return Err("No supported present mode found")

  if not SDL_SetGPUSwapchainParameters(device, window, SDL_GPU_SWAPCHAINCOMPOSITION_SDR, presentMode):
    return Err($SDL_GetError())

  var vertexShaderInfo = SDL_GPUShaderCreateInfo(
    code_size: vertexShaderBin.len.csize_t,
    code: cast[ptr UncheckedArray[uint8]](vertexShaderBin.cstring.pointer),
    entrypoint: "main".cstring,
    format: SDL_GPU_SHADERFORMAT_SPIRV.uint32, # Push a patch for this
    stage: SDL_GPU_SHADERSTAGE_VERTEX,
    num_samplers: 0,
    num_uniform_buffers: 0,
    num_storage_buffers: 0,
    num_storage_textures: 0,
    props: 0,
  )
  var vertShader = SDL_CreateGPUShader(device, addr vertexShaderInfo)
  if vertShader.isNil:
    return Err($SDL_GetError())
  defer: SDL_ReleaseGPUShader(device, vertShader)

  var fragmentShaderInfo = SDL_GPUShaderCreateInfo(
    code_size: fragmentShaderBin.len.csize_t,
    code: cast[ptr UncheckedArray[uint8]](fragmentShaderBin.cstring.pointer),
    entrypoint: "main".cstring,
    format: SDL_GPU_SHADERFORMAT_SPIRV.uint32,
    stage: SDL_GPU_SHADERSTAGE_FRAGMENT,
    num_samplers: 0,
    num_uniform_buffers: 0,
    num_storage_buffers: 0,
    num_storage_textures: 0,
    props: 0,
  )
  var fragShader = SDL_CreateGPUShader(device, addr fragmentShaderInfo)
  if fragShader.isNil:
    return Err($SDL_GetError())
  defer: SDL_ReleaseGPUShader(device, fragShader)

  var colorTargetDesc = [
    SDL_GPUColorTargetDescription(
      format: SDL_GetGPUSwapchainTextureFormat(device, window),
      blend_state: SDL_GPUColorTargetBlendState(
        enable_blend: true,
        alpha_blend_op: SDL_GPU_BLENDOP_ADD,
        color_blend_op: SDL_GPU_BLENDOP_ADD,
        color_write_mask: 0xF,
        src_alpha_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
        dst_alpha_blendfactor: SDL_GPU_BLENDFACTOR_DST_ALPHA,
        src_color_blendfactor: SDL_GPU_BLENDFACTOR_SRC_ALPHA,
        dst_color_blendfactor: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
      ),
    )
  ]

  var vertexBufferDescriptions = [
    SDL_GPUVertexBufferDescription(
      slot: 0,
      input_rate: SDL_GPU_VERTEXINPUTRATE_VERTEX,
      instance_step_rate: 0,
      pitch: sizeof(Vec2).uint32,
    )
  ] 

  var vertexAttributes = [
    SDL_GPUVertexAttribute(
      buffer_slot: 0,
      format: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
      location: 0,
      offset: 0,
    )
  ]

  var targetInfo = SDL_GPUGraphicsPipelineTargetInfo(
    num_color_targets: 1,
    color_target_descriptions: cast[ptr UncheckedArray[SDL_GPUColorTargetDescription]](addr colorTargetDesc),
    has_depth_stencil_target: false,
  )

  var vertexInputState = SDL_GPUVertexInputState(
    num_vertex_buffers: 1,
    vertex_buffer_descriptions: cast[ptr UncheckedArray[SDL_GPUVertexBufferDescription]](addr vertexBufferDescriptions),
    num_vertex_attributes: 1,
    vertex_attributes: cast[ptr UncheckedArray[SDL_GPUVertexAttribute]](addr vertexAttributes),
  )

  var pipelineInfo = SDL_GPUGraphicsPipelineCreateInfo(
    target_info: targetInfo,
    vertex_input_state: vertexInputState,
    primitive_type: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
    vertex_shader: addr vertShader,
    fragment_shader: addr fragShader,
  )

  var pipeline = SDL_CreateGPUGraphicsPipeline(
    device, 
    addr pipelineInfo
  )

  if pipeline.isNil:
    return Err($SDL_GetError())

  result = Ok(T(camera: Camera(x: 0, y: 0), pipeline: pipeline))