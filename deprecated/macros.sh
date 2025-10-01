#!/bin/sh

chosen=$(grep -v "%" /home/artin/Vshrd/macros/index | rofi -dpi 160 -show dmenu -p "select macro" -i -l 20)
[ "$chosen" != "" ] || exit
echo $chosen
c="/home/artin/Vshrd/macros/$chosen"
cat "$c" |  wl-copy && echo "Copied!"
