import coral/[core, platform, artist]
import random, math
import chroma

plugin MenuScene:
  proc load() = registerScene("MenuScene")
  proc loadScene() =
    discard

  proc update(cmds: var Commands) =
    if space.pressed:
      cmds.pushScene("GameScene")

  proc draw(artist: var Artist) =
    artist.layer(1):
      rect(10.0, 200.0, 100.0, 100.0, color = color(0.0, 1.0, 0.0, 1.0))

plugin MenuAux:
  proc draw(artist: var Artist) =
    rect(200.0, 200.0 + sin(clockTimer()) * 100.0, 100.0, 100.0, color = color(0.0, 1.0, 0.0, 1.0))