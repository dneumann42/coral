# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest, chroma

import coral/core/platform2

test "can add":
  initializeWindow()

  while updateWindow():
    if K_left.isPressed():
      echo "A"

    if a.isReleased():
      echo "B"

    withDrawing:
      clearBackground(color(0.1, 0.1, 0.1, 1.0))
