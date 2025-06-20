#!/usr/bin/env bash

set -e

read -rp "Enter commit message: " COMMIT_MESSAGE
cp "$HOME/.bash_aliases" ./bash_aliases
git add .
git commit -m "$COMMIT_MESSAGE"
git push origin HEAD
