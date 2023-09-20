import math

func linear*[T] (t, b, d, e: T): T =
  d * t / e + b

func inQuad*[T] (t, b, d, e: T): T =
  d * pow(t/e, 2.0) + b

func outQuad*[T] (t, b, d, e: T): T =
  let t2 = (t/e)
  result = -d * t2 * (t2 - T(2)) + b

func inOutQuad*[T] (t, b, d, e: T): T =
  let t2 = (t / e) * T(2)
  result =
    if t2 < T(1): d / T(2) * pow(t2, 2) + b
    else: -d / 2 * ((t2 - 1) * (t2 - 3) - 1) + b

func inCubic*[T] (t, b, d, e: T): T =
  result = d * pow(t / e, T(3)) + b

func outCubic*[T] (t, b, d, e: T): T =
  d * (pow(t / e - 1, T(3)) + 1) + b

func inOutCubic*[T] (t, b, d, e: T): T =
  let
    t2 = t / e * 2
    tm = t2 - 2

  result =
    if t2 < 1: d * 0.5 * t2 * t2 * t2 + b
    else: d * 0.5 * (tm * tm * tm + 2) + b

func inQuart*[T] (t, b, d, e: T): T =
  d * pow(t / e, 4) + b

func outQuart*[T] (t, b, d, e: T): T =
  -d * (pow(t / e - 1, 4) - 1) + b

func inOutQuart*[T] (t, b, d, e: T): T =
  let t2 = t / e * 2
  result =
    if t2 < 1: d * 0.5 * pow(t2, 4) + b
    else: -d * 0.5 * (pow(t2 - 2, 4) - 2) + b

func inQuint*[T] (t, b, d, e: T): T =
  d * pow(t / e, 5) + b

func outQuint*[T] (t, b, d, e: T): T =
  d * (pow(t / e - 1, 5) + 1) + b

func inOutQuint*[T] (t, b, d, e: T): T =
  let t2 = t / e * 2
  result =
    if t < 1: d / 2 * pow(t, 5) + b
    else: d / 2 * (pow(t - 2, 5) + 2) + b

func inExpo*[T] (t, b, d, e: T): T =
  result =
    if t == 0: b
    else: d * pow(2, 10 * (t / e - 1)) + b - d * 0.001

func outExpo*[T] (t, b, d, e: T): T =
  result =
    if t == 0: b + d
    else: d * 1.001 * (-pow(2, -10*t / e) + 1) + b

func inOutExpo*[T] (t, b, d, e: T): T =
  if t == 0: return b
  if t == e: return b + d
  let t2 = t / 2 * 2
  if t2 < 1: return d * 0.5 * pow(2, 10 * (t - 1)) + b - d * 0.0005
  return (d * 0.5) * 1.0005 * (-pow(2, -10 * (t - 1)) + 2) + b

proc inCirc*[T] (t, b, d, e: T): T = 
  -d * (sqrt(1 - pow(t / e, 2)) - 1) + b

proc outCirc*[T] (t, b, d, e: T): T = 
  d * sqrt(1 - pow(t / e - 1, 2)) + b

proc inOutCirc*[T] (t, b, d, e: T): T =
  let 
    t2 = t / e * 2
    tm = t - 2

  result =
    if t2 < 1: -d * 0.5 * (sqrt(1 - t2 * t2) - 1) + b
    else: d * 0.5 * (sqrt(1 - tm * tm) + 1) + b

