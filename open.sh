#!/bin/bash

cd "$HOME/" || exit 1

SEARCH_PATHS=(
  "Vshrd/"
  ".config/"
)
DRAWIO_DIR="$HOME/clones/drawio-desktop"
TERMINAL="kitty"  # change to kitty, alacritty, etc.

RECENT_FILE="$HOME/Vshrd/shell-scripts/open_sh_recents"
mkdir -p "$(dirname "$RECENT_FILE")"
touch "$RECENT_FILE"

update_recents() {
  local current="$1"
  local tmp="${RECENT_FILE}.tmp"

  {
    printf '%s\n' "$current"
    while IFS= read -r f; do
      [ "$f" != "$current" ] && [ -f "$f" ] && printf '%s\n' "$f"
    done < "$RECENT_FILE"
  } | awk '!seen[$0]++' | head -n 10 > "$tmp" && mv "$tmp" "$RECENT_FILE"
}

show_recent=false

while getopts "r" opt; do
  case "$opt" in
    r) show_recent=true ;;
  esac
done

if $show_recent; then
  # Show recent files only, newest first
  file=$(
    while IFS= read -r f; do
      [ -f "$f" ] && realpath --relative-to="$HOME/" "$f"
    done < "$RECENT_FILE" | fuzzel --dmenu -l 10 -w 80
  )
else
  file=$(
    find \
      "${SEARCH_PATHS[@]}" \
      -type f \
      ! -path '*/.git/*' \
      ! -path '*/node_modules/*' \
      ! -path '*/__pycache__/*' \
      ! -path '*/music/*' \
      | fuzzel --dmenu -l 10 -w 80
  )
fi

# Exit if nothing was selected
[ -z "$file" ] && exit 0

selected="$HOME/$file"
[ ! -f "$selected" ] && exit 1

update_recents "$selected"

case "$selected" in
  *.md|*.txt|*.puml|*.yaml|*.yml|*.toml|*.json|\
  *.sh|*.bash|*.fish|*.zsh|*.kdl|\
  *.py|*.rs|*.go|*.c|*.h|*.cpp|*.hpp|*.java|\
  *.js|*.ts|*.lua|*.nix|*.tex|*.typ|\
  *.css|*.html|*.xml|\
  *.conf|*.ini|*.cfg|*.org)
    echo $selected
    "$HOME/Vshrd/shell-scripts/neovim_handler.sh" "$selected" &
    ;;

  *.pdf)
choice=$(printf "zathura\nxournalpp\nkrita" | fuzzel --dmenu --prompt "Pick: ")
    case "$choice" in
      "zathura")
        zathura "$selected" &
        ;;
      "xournalpp")
        xournalpp "$selected" &
        ;;
      "krita")
        krita "$selected" &
        ;;
    esac
    ;;

  *.rnote)
    flatpak run com.github.flxzt.rnote "$selected" &
    ;;

  *.epub)
    zathura "$selected" &
    ;;

  *.drawio)
    (cd "$DRAWIO_DIR" && npm start -- "$(realpath "$selected")") &>/dev/null &
    ;;

  *.kra)
    (krita "$selected" &
    ;;

  *.excalidraw|*.excalidraw.json)
    xdg-open "$selected" &
    ;;

  *.xopp)
    xournalpp "$selected" &
    ;;

  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp)
    mupdf "$selected" &
    ;;

  *.svg)
    mupdf "$selected" &
    ;;
  *.ods)
    libreoffice "$selected" &
    ;;

  *)
    if file --mime-type -b "$selected" | grep -q "^text/"; then
      $TERMINAL -e hx "$selected" &
    fi
    ;;
esac

disown
