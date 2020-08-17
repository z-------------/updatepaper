# Package

version       = "0.0.0"
author        = "Zack Guard"
description   = "Command line interface for updating Paper. Clone of my original update-paper for Node.js."
license       = "MIT"
srcDir        = "src"
bin           = @["updatepaper"]



# Dependencies

requires "nim >= 1.2.6"
requires "docopt >= 0.6.8"
