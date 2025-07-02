#!/usr/bin/env bash

export DISPLAY=:0
# export TESSDATA_PREFIX=/usr/share/tesseract-ocr/5/
flameshot gui --raw | tesseract -l eng stdin stdout | xclip -selection clipboard

