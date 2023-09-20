import tweenfns as fns

type
  EasingFn = proc(time, begin, delta, elapsed: SomeNumber): SomeNumber
  EasingKind* = enum
    linear

    inQuad
    outQuad
    inOutQuad

    inCubic
    outCubic
    inOutCubic

    inQuart
    outQuart
    inOutQuart

    inQuint
    outQuint
    inOutQuint

    inSine
    outSine
    inOutSine

    inExpo
    outExpo
    inOutExpo

    inCirc
    outCirc
    inOutCirc

    inElastic
    outElastic
    inOutElastic

    inBack
    outBack
    inOutBack

    inBounce
    outBounce
    inOutBounce


  Tween*[T] = object
    time: T
    init, value, target: T
    duration: float
    easing: EasingKind

proc lerp*[T](a, b, t: T): T = a + (b - a) * t

func value*[T](tween: Tween[T]): T = tween.value

proc newTween*[T](init, target, duration: T, easing: EasingKind): Tween[T] =
  Tween[T](
    init: init,
    value: init,
    target: target,
    duration: duration,
    easing: easing
  )

proc isDone*[T] (tween: Tween[T]): bool =
  tween.time >= tween.duration

proc interpolate*[T] (tween: var Tween[T]) =
  let
    time = tween.time
    begin = tween.init
    delta = tween.target - tween.init
    elapsed = tween.duration

  tween.value =
    case tween.easing
      of linear: fns.linear(time, begin, delta, elapsed)

      of inQuad: fns.inQuad(time, begin, delta, elapsed)
      of outQuad: fns.outQuad(time, begin, delta, elapsed)
      of inOutQuad: fns.inOutQuad(time, begin, delta, elapsed)

      of inCubic: fns.inCubic(time, begin, delta, elapsed)
      of outCubic: fns.outCubic(time, begin, delta, elapsed)
      of inOutCubic: fns.inOutCubic(time, begin, delta, elapsed)

      of inQuart: fns.inQuart(time, begin, delta, elapsed)
      of outQuart: fns.outQuart(time, begin, delta, elapsed)
      of inOutQuart: fns.inOutQuart(time, begin, delta, elapsed)

      of inQuint: fns.inQuint(time, begin, delta, elapsed)
      of outQuint: fns.outQuint(time, begin, delta, elapsed)
      of inOutQuint: fns.inOutQuint(time, begin, delta, elapsed)

      of inExpo: fns.inExpo(time, begin, delta, elapsed)
      of outExpo: fns.outExpo(time, begin, delta, elapsed)
      of inOutExpo: fns.inOutExpo(time, begin, delta, elapsed)

      of inCirc: fns.inCirc(time, begin, delta, elapsed)
      of outCirc: fns.outCirc(time, begin, delta, elapsed)
      of inOutCirc: fns.inOutCirc(time, begin, delta, elapsed)

      else:
        tween.value

proc reset*[T] (tween: var Tween[T]): bool =
  set(0)

proc set*[T] (tween: var Tween[T], time: T): bool =
  tween.time = time

  if tween.time <= 0:
    tween.time = 0
    tween.value = tween.target
  elif tween.time >= tween.duration:
    tween.time = tween.duration
    tween.value = tween.target
  else:
    interpolate(tween)

  result = tween.isDone

proc update*[T] (tween: var Tween[T], deltatime: T): bool {.discardable.} =
  result = tween.set(tween.time + deltatime)
