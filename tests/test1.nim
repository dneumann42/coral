import coral

plugin Demo:
  proc load() =
    echo "LOADING DEMO"

when isMainModule:
  var app = Application.init().get()
  initializePlugins(app)

  while app.running:
    app.beginFrame()

    app.endFrame()
