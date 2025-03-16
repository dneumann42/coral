{.push raises: [].}

import std / [ macros, options, logging ]
import results
export results, logging, options

macro O* (T: untyped, procedure: untyped): untyped =
  procedure[3][0] = nnkBracketExpr.newTree(newIdentNode("Option"), ident(T.repr)) 
  procedure[^1].insert(0, 
    quote do:
      template Some(x: `T`): Option[`T`] = some(x)
      template None(): Option[`T`] = `T`.none()
  )
  return procedure

macro R* (T, E: untyped, procedure: untyped): untyped =
  procedure[3][0] = nnkBracketExpr.newTree(newIdentNode("Result"), ident(T.repr), ident(E.repr)) 
  procedure[^1].insert(0, 
    quote do:
      template Ok(x: `T`): Result[`T`, `E`] = ok(x)
      template Err(x: `E`): Result[`T`, `E`] = err(x)
  )
  return procedure

template withIt* [T] (o: Option[T], blk: untyped): auto =
  block:
    let o1 = o
    if o1.isSome():
      let it {.inject.} = o1.get()
      blk

template raiseError* (s: string): auto =
  raise CatchableError.newException(s)
