import coral/[core, platform, artist]
import random
import chroma

plugin MenuScene:
  proc load() = registerScene("MenuScene")
  proc loadScene() =
    discard

  proc update(cmds: var Commands) =
    if space.press:
      cmds.pushScene("GameScene")

  proc draw(artist: var Artist) =
    artist.layer(1):
      rect(10.0, 200.0, 100.0, 100.0, color = color(0.0, 1.0, 0.0, 1.0))