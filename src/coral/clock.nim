type
  Clock* = object
    dt*: float
    avgDt*: float
    ticks*: int

proc fps* (clock: Clock): float =
  if clock.dt == 0.0:
    return 0.0
  result = (1.0 / clock.dt)

proc avgFps* (clock: Clock): float =
  if clock.avgDt == 0.0:
    return 0.0
  result = (1.0 / clock.avgDt)
