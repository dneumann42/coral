import unittest, chroma, vmath, options, macros

import coral/[core, platform, ents]
import menuscene, gamescene

var game = Game.init(
  "Test",
  "MenuScene".some(),
  title = "Test"
)

expandMacros:
  start(game)
