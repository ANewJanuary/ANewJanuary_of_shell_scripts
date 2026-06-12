#!/bin/bash
REGION=$(slurp) || exit 1
grim -g "$REGION" - | magick - -resize 80% -negate -strip png:- | wl-copy --type image/png
notify-send "Screenshot ready" "Paste with <leader>pi"
