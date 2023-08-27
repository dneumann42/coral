type
  List[T] = concept s, var v
    s.pop() is T
    v.push(T)

    s.`[]` is T
    v.`[]=`(T)

    s.len is Ordinal

    for value in s:
      value is T
