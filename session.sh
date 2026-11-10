#!/bin/bash

SESSIONS=("spe")

chosen=$(printf '%s\n' "${SESSIONS[@]}" | fuzzel --dmenu --prompt "Session: ")
[ -z "$chosen" ] && exit 1

if [ "$chosen" == "spe" ]; then
  drawio /home/artin/Vshrd/LP/sketchbox.drawio &
  ipe &
  zathura /home/artin/Vshrd/LP/spe/master.pdf &
  niri msg action focus-workspace ᛟ &
  kitty --directory /home/artin/Vshrd/LP/spe/computations/ \
    --hold fish -c "zellij attach -c workflow" &
fi
