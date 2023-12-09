import unittest, chroma, vmath, options, macros

import coral/[core, platform]
import menuscene, gamescene

plugin(ResourceLoader):
  proc load() =
    loadImage("tests/peppers.png")
    loadFont("tests/DungeonFont.ttf", 72)

test "it can play games":
  var game = Game.init(title = "Test game", startingScene = "MenuScene".some)
  expandMacros:
    game.start()
