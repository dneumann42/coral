import vmath, bumpy

proc lerp* [T: SomeFloat] (a, b, t: T): T =
  a + (b - a) * t

proc lerpPercent* [T: SomeFloat] (a, b, t: T): T =
  (a * (1.0 - t)) + (b * t)

export vmath, bumpy
