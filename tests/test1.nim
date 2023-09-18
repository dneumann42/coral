# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, chroma, vmath

import coral/platform/application
import coral/platform/renderer

test "can add":
  initializeWindow()

  loadImage("tests/peppers.png")

  while updateWindow():
    if left.isPressed():
      echo "A"

    if a.isReleased():
      echo "B"

    withDrawing:
      rect(
        sin(clockTimer() * 10.0) * 10.0 + 100.0,
        cos(clockTimer() * 10.0) * 10.0 + 100.0, 100.0, 100.0)

      circle(
        sin(clockTimer() * 5.0) * 20.0 + 400.0,
        cos(clockTimer() * 10.0) * 10.0 + 100.0, 
        150 + sin(clockTimer()) * 50.0, 
        color(0.0, 0.5, 1.0, 1.0))

      texture(
        "peppers", 
        (100.0, 100.0, 100.0, 100.0), 
        (100.0, 100.0, 100.0, 100.0)
      )
