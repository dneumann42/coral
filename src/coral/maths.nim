import vmath, bumpy
export vmath, bumpy

proc lerp* [T: SomeFloat] (a, b, t: T): T =
  a + (b - a) * t

proc lerpPercent* [T: SomeFloat] (a, b, t: T): T =
  (a * (1.0 - t)) + (b * t)

proc `+`* (a, b: tuple[x, y: int]): tuple[x, y: int] =
  result = (a.x + b.x, a.y + b.y)

proc `-`* (a, b: tuple[x, y: int]): tuple[x, y: int] =
  result = (a.x - b.x, a.y - b.y)

proc `*`* (a, b: tuple[x, y: int]): tuple[x, y: int] =
  result = (a.x * b.x, a.y * b.y)

proc `/`* (a, b: tuple[x, y: int]): tuple[x, y: int] =
  result = (a.x div b.x, a.y div b.y)
