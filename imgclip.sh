set -euo pipefail

BASE_DIR="$HOME/Vshrd/LP/notes/attach"

REGION=$(slurp) || exit 1
grim -g "$REGION" - | magick - -resize 80% -strip png:- | wl-copy --type image/png
notify-send "Screenshot" "Captured"

FILENAME=$(fuzzel --dmenu --prompt "Filename (no ext): " < /dev/null)
[ -z "$FILENAME" ] && exit 1

NEGATE=$(printf 'no\nyes\n' | fuzzel --dmenu --prompt "Negate colors? ")
[ -z "$NEGATE" ] && exit 1

TARGET_DIR="$BASE_DIR"
TARGET_FILE="$TARGET_DIR/$FILENAME.png"

if [ -e "$TARGET_FILE" ]; then
  notify-send "img-clip" "File exists, aborting: $TARGET_FILE"
  exit 1
fi

wl-paste --type image/png > "$TARGET_FILE"

if [ "$NEGATE" = "yes" ]; then
  magick "$TARGET_FILE" -negate "$TARGET_FILE"
fi

# now org mode
SNIPPET="#+ATTR_ORG: :width 400 :align center
[[file:$TARGET_FILE]]"

printf '%s' "$SNIPPET" | wl-copy
notify-send "Saved" "$TARGET_FILE — snippet on clipboard"
