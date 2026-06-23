#!/bin/bash
set -euo pipefail

BASE_DIR="$HOME/LP"           # adjust to your actual LP root
DOMAINS=("ECU" "BMS" "TSM")

# --- capture ---
REGION=$(slurp) || exit 1
grim -g "$REGION" - | magick - -resize 80% -strip png:- | wl-copy --type image/png
notify-send "Screenshot" "Captured, choose domain..."

# --- prompts ---
DOMAIN=$(printf '%s\n' "${DOMAINS[@]}" | fuzzel --dmenu --prompt "Domain: ")
[ -z "$DOMAIN" ] && exit 1

FILENAME=$(fuzzel --dmenu --prompt "Filename (no ext): " < /dev/null)
[ -z "$FILENAME" ] && exit 1

NEGATE=$(printf 'no\nyes\n' | fuzzel --dmenu --prompt "Negate colors? ")
[ -z "$NEGATE" ] && exit 1

# --- save ---
TARGET_DIR="$BASE_DIR/attachments/$DOMAIN"
mkdir -p "$TARGET_DIR"
TARGET_FILE="$TARGET_DIR/$FILENAME.png"

if [ -e "$TARGET_FILE" ]; then
  notify-send "img-clip" "File exists, aborting: $TARGET_FILE"
  exit 1
fi

wl-paste --type image/png > "$TARGET_FILE"

if [ "$NEGATE" = "yes" ]; then
  magick "$TARGET_FILE" -negate "$TARGET_FILE"
fi

# --- emit Typst snippet to clipboard, ready to paste in ANY editor ---
SNIPPET="#figure(
  image(\"attachments/$DOMAIN/$FILENAME.png\"),
  caption: [],
) <fig-$DOMAIN-$FILENAME>"

printf '%s' "$SNIPPET" | wl-copy
notify-send "Saved" "$TARGET_FILE — snippet on clipboard"
