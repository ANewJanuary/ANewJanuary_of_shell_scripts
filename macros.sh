chosen=$(ls /home/orpheus/Vshrd/macros/ | fuzzel --dmenu -l 10 -w 80)
[ "$chosen" != "" ] || exit
c="/home/orpheus/Vshrd/macros/$chosen"
cat "$c" |  wl-copy && echo "Copied!"
