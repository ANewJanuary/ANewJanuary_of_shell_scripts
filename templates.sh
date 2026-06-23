#!/bin/bash

TEMPLATE="$HOME/Vshrd/shell-scripts/templates/$(cd $HOME/Vshrd/shell-scripts/templates/ && ls | fuzzel --dmenu -l 10 -w 80)"

read -p "Filename: " name
cp "$TEMPLATE" "$name"
mv "$name" "$PWD/$name"
