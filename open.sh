SEARCH_PATHS=(
  "$HOME/.config"
  "$HOME/Vshrd"
)
DRAWIO_DIR="$HOME/clones/drawio-desktop"

TERMINAL="kitty"  # change to kitty, alacritty, etc.

selected=$(find \
  "${SEARCH_PATHS[@]}" \
  -type f \
  ! -path '*/.git/*' \
  ! -path '*/node_modules/*' \
  ! -path '*/__pycache__/*' \
  | fuzzel --dmenu -l 10 -w 60)

# Exit if nothing was selected
[ -z "$selected" ] && exit 0

case "$selected" in
  # Text files → Helix in a new terminal
  *.md|*.txt|*.puml|*.yaml|*.yml|*.toml|*.json|\
  *.sh|*.bash|*.fish|*.zsh|\
  *.py|*.rs|*.go|*.c|*.h|*.cpp|*.hpp|*.java|\
  *.js|*.ts|*.lua|*.nix|*.tex|*.typ|\
  *.css|*.html|*.xml|*.svg|\
  *.conf|*.ini|*.cfg)
    $TERMINAL -e hx "$selected" &
    ;;

  # PDF → Zathura (will auto-group via Hyprland rules)
  *.pdf)
    zathura "$selected" &
    ;;

  *.epub)
    zathura "$selected" &
    ;;

  # Draw.io diagrams
  *.drawio)
    (cd "$DRAWIO_DIR" && npm start -- "$(realpath "$selected")") &>/dev/null &
    ;;

  # Excalidraw files
  *.excalidraw|*.excalidraw.json)
    xdg-open "$selected" &
    ;;

  # Xournal++ files
  *.xopp)
    xournalpp "$selected" &
    ;;

  # Images
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp)
    imv "$selected" &
    ;;

  *.svg)
    # SVGs could be edited (text) or viewed (image) — defaulting to view
    imv "$selected" &
    ;;

  # Fallback: try to detect if it's a text file, otherwise xdg-open
  *)
    if file --mime-type -b "$selected" | grep -q "^text/"; then
      $TERMINAL -e hx "$selected" &
    else
      xdg-open "$selected" &
    fi
    ;;
esac

# Disown background processes so they don't die with the script
disown
