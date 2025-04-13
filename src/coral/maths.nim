import vmath, bumpy
export vmath, bumpy

proc lerp* [T: SomeFloat] (a, b, t: T): T =
  a + (b - a) * t

proc lerpPercent* [T: SomeFloat] (a, b, t: T): T =
  (a * (1.0 - t)) + (b * t)

proc `+`* [T] (a, b: tuple[x, y: T]): tuple[x, y: T] =
  result = (a.x + b.x, a.y + b.y)

proc `-`* [T] (a, b: tuple[x, y: T]): tuple[x, y: T] =
  result = (a.x - b.x, a.y - b.y)

proc `*`* [T] (a, b: tuple[x, y: T]): tuple[x, y: T] =
  result = (a.x * b.x, a.y * b.y)

proc `/`* [T] (a, b: tuple[x, y: T]): tuple[x, y: T] =
  result = (a.x div b.x, a.y div b.y)
