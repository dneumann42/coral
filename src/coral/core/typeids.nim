import hashes, tables, macros

type
  TypeId* = Hash

var typeIds {.compileTime.} = initTable[int, string]()

macro getTypeId*(t: typed): TypeId =
  let name = $getTypeImpl(t)[1]
  var h = hash(name) mod 2147483645
  while true:
    if h in typeIds:
      if typeIds[h] == name: break
      h = (h *% 2) mod 2147483645
    else:
      typeIds[h] = name
      break
  result = newLit(h)
