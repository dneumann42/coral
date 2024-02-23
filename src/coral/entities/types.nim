import json, hashes, tables

type
  EntId* = distinct int

proc `%`*(i: EntId): JsonNode = % (i.int)
proc `$`*(i: EntId): string = $(i.int)

proc hash*(h: EntId): Hash {.borrow.}
proc `==`*(a, b: EntId): bool {.borrow.}
