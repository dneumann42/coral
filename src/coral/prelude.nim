{.push raises: [].}

import std / [ macros, options ]
import results
export results

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
