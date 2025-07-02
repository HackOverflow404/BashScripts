#!/usr/bin/env bash

# Optional: Ensure environment is loaded
export DISPLAY=:0
# export TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/

# Run the actual command
flameshot gui --raw | tesseract -l eng stdin stdout | xclip -selection clipboard

