#!/bin/bash



SEARCH_PATHS=(
  "$HOME/Vshrd"
)

cd /home/artin/Vshrd/

selected=$(find \
  ./ \
  -type f \
  ! -path '*/.git/*' \
  ! -path '*/node_modules/*' \
  ! -path '*/__pycache__/*' \
  ! -path '*/.stversions/*' \
  ! -path '*/.stfolder/*' \
  ! -path '*/config/*' \
  | fuzzel --dmenu -l 10 -w 60)

  echo "$HOME/Vshrd/$selected" | wl-copy
