# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, chroma, vmath, options

import coral/[platform, artist, core]
import coral/core/plugins2
import menu

proc resourceLoader() =
  loadImage("tests/peppers.png")
  loadFont("tests/DungeonFont.ttf", 72)

proc mainMenu(plugins: var Plugins) =
  proc load() =
    discard

  proc update(cmds: var Commands) =
    if K_return.press: 
      cmds.changeScene("gamescene")

  proc draw() =
    rect(100.0, 100.0, 100.0, 100.0, color=color(0.0, 1.0, 0.5, 1.0))
    text("Hello, World!", "DungeonFont", 300.0, 300.0)

  # plugins.scene("mainmenu", load, update, draw)

proc gameScene(plugins: var Plugins) =
  proc load() =
    discard

  proc update(cmds: var Commands) =
    if K_return.press: 
      cmds.changeScene("mainmenu")

  proc draw() =
    rect(100.0, 100.0, 100.0, 100.0, color=color(1.0, 0.5, 0.1, 1.0))

test "it can play games":
  var game = Game.init(title = "Test game", startingScene = "mainmenu".some)
  # game.plugins.loading()
  # game.plugins.mainMenu()
  # game.plugins.gameScene()
  
  register("menu", load, loadMenu)
  register("menu", update, updateMenu)
  register("menu", draw, drawMenu)

  game.start()
