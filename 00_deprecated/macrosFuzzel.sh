#!/bin/sh

chosen=$(ls /home/artin/Vshrd/macros/ | fuzzel --dmenu -l 10 -w 80)
[ "$chosen" != "" ] || exit
c="/home/artin/Vshrd/macros/$chosen"
cat "$c" |  wl-copy && echo "Copied!"
