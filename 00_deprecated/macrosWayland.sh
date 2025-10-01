#!/bin/sh

chosen=$(grep -v "%" /home/artin/Documents/Vshrd/macros/index | rofi -dpi 160 -dmenu -p "select macro" -i -l 20)
[ "$chosen" != "" ] || exit
c="/home/artin/Documents/Vshrd/macros/$chosen"
xsel -cb
cat "$c" |  wl-copy && echo "Copied!"
