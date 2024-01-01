import std/hashes

type
  EntId* = distinct int

proc `==`*(a, b: EntId): bool {.borrow.}
proc hash*(a: EntId): Hash {.borrow.}