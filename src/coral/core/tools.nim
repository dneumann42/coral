import options, macros

macro `?`*[T](op: Option[T]): untyped =
  quote do:
    if `op`.isNone:
      return
    `op`.get()

proc permutations*[T](items: openArray[T], number = 1): seq[seq[T]] =
  proc perm(a: openArray[T], n: int, use: var seq[bool]): seq[seq[T]] =
    result = newSeq[seq[T]]()
    if n <= 0: return
    for i in 0 .. a.high:
      if not use[i]:
        if n == 1:
          result.add(@[a[i]])
        else:
          use[i] = true
          for j in perm(a, n - 1, use):
            result.add(a[i] & j)
          use[i] = false
  var use = newSeq[bool](items.len)
  perm(items, number, use)
