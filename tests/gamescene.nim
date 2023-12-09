import coral/[core, platform, artist]
import chroma

plugin GameScene:
  proc load() = registerScene("GameScene")
  proc loadScene(cmds: var Commands) =
    discard

  proc update(game: Game) =
    discard

  proc draw(artist: var Artist) =
    artist.layer(1):
      rect(10.0, 10.0, 100.0, 100.0, color=color(1.0, 0.0, 0.0, 1.0)) 