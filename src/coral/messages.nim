type
  AbstractMessage* = ref object of RootObj
    handled* = false
  Message* [T] = ref object of AbstractMessage
    when T isnot void:
      state*: T

template handleWhen* (msg: AbstractMessage, T: type, blk: untyped): auto =
  if msg of T and not msg.handled:
    let it {.inject.} = msg.T
    blk
    msg.handled = true

template whenIs* (msg: AbstractMessage, T: type, blk: untyped): auto =
  if msg of T:
    let it {.inject.} = msg.T
    blk
