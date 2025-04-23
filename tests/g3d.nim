import coral

type
  DrawTest = ref object of Plugin

method draw(self: DrawTest) =
  echo "HERE?"

when isMainModule:
  var app = Application
    .init()
    .get()
  app
    .add(DrawTest())
    .run()
