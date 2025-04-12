from sdl3 import SDL_Color, SDL_FColor

type Color* = SDL_FColor

proc colorToFColor* (color: SDL_Color): SDL_FColor =
  ## Converts SDL_Color (byte 0-255) to SDL_FColor (floating point 0.0-1.0)
  
  result.r = float(color.r) / 255.0
  result.g = float(color.g) / 255.0
  result.b = float(color.b) / 255.0
  result.a = float(color.a) / 255.0

proc rgba* (colorInt: uint32): SDL_FColor =
  let
    r: uint8 = (colorInt shr 24).uint8 and 0xFF
    g: uint8 = (colorInt shr 16).uint8 and 0xFF
    b: uint8 = (colorInt shr 8).uint8 and 0xFF
    a: uint8 = (colorInt).uint8 and 0xFF
  result = SDL_Color(r: r, g: g, b: b, a: a).colorToFColor()

const Black* = 0x000000ff'u32.rgba
const White* = 0xffffffff'u32.rgba
const Transparent* = 0x00000000'u32.rgba
const DarkChocolate* = 0x472d3cff'u32.rgba
const Chocolate* = 0x5e3643ff'u32.rgba
const DarkBrown* = 0x7a444aff'u32.rgba
const Brown* = 0xa05b53ff'u32.rgba
const LightBrown* = 0xbf7958ff'u32.rgba
const DarkTan* = 0xeea160ff'u32.rgba
const Tan* = 0xf4cca1ff'u32.rgba
const BrightGreen* = 0xb6d53cff'u32.rgba
const LimeGreen* = 0x71aa34ff'u32.rgba
const Green* = 0x397b44ff'u32.rgba
const DarkGreen* = 0x3c5956ff'u32.rgba
const DarkGray* = 0x302c2eff'u32.rgba
const Gray* = 0x7d7071ff'u32.rgba
const LightGray* = 0xa0938eff'u32.rgba
const BrightGray* = 0xcfc6b8ff'u32.rgba
const SkyBlue* = 0xdff6f5ff'u32.rgba
const LightBlue* = 0x28ccdfff'u32.rgba
const Blue* = 0x3978a8ff'u32.rgba
const DarkBlue* = 0x394778ff'u32.rgba
const DarkSlateGray* = 0x39314bff'u32.rgba
const DarkPurple* = 0x56064ff'u32.rgba
const Purple* = 0x8e478cff'u32.rgba
const HotPink* = 0xcd6093ff'u32.rgba
const Pink* = 0xffaeb6ff'u32.rgba
const Yellow* = 0xf4b41bff'u32.rgba
const Orange* = 0xf47e1bff'u32.rgba
const DarkOrange* = 0xe6582eff'u32.rgba
const Red* = 0xa93b3bff'u32.rgba
const Lavendar* = 0x827094ff'u32.rgba
const SlateGray* = 0x4f546bff'u32.rgba

const DefaultPalette* = [
  Black,
  White,
  Transparent,
  DarkChocolate,
  Chocolate,
  DarkBrown,
  Brown,
  LightBrown,
  DarkTan,
  Tan,
  BrightGreen,
  LimeGreen,
  Green,
  DarkGreen,
  DarkGray,
  Gray,
  LightGray,
  BrightGray,
  SkyBlue,
  LightBlue,
  Blue,
  DarkBlue,
  DarkSlateGray,
  DarkPurple,
  Purple,
  HotPink,
  Pink,
  Yellow,
  Orange,
  DarkOrange,
  Red,
  Lavendar,
  SlateGray
]
