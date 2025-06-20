#!/usr/bin/env bash

read -p "Enter commit message: " COMMIT_MESSAGE
cp ~/.bash_aliases ./bash_aliases
git add .
git commit -m $COMMIT_MESSAGE
git push origin main
