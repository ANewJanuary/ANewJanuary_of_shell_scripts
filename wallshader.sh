#!/usr/bin/env bash
# Switch the niri shader wallpaper.
#   wallshader.sh            cycle to the next shader in ~/.config/niri/shaders
#   wallshader.sh <name>     switch to <name>.frag (e.g. "hud", "bg")
#   wallshader.sh --restore  start the last used shader (for login)
#   wallshader.sh --list     list available shaders
#
# Default fps is below; a shader can override it with a "// fps: N" line at the top.

dir="$HOME/Vshrd/shell-scripts/shaders"
state="${XDG_STATE_HOME:-$HOME/.local/state}/wallshader"
fps=144

shaders=()
for f in "$dir"/*.frag; do shaders+=("$(basename "$f" .frag)"); done
[[ ${#shaders[@]} -eq 0 ]] && { echo "no shaders in $dir" >&2; exit 1; }

current=$(cat "$state" 2>/dev/null)

case "$1" in
  --list) printf '%s\n' "${shaders[@]}"; exit 0 ;;
  --restore) next="${current:-${shaders[0]}}" ;;
  "")
    next="${shaders[0]}"
    for i in "${!shaders[@]}"; do
      if [[ ${shaders[$i]} == "$current" ]]; then
        next="${shaders[$(( (i + 1) % ${#shaders[@]} ))]}"
      fi
    done ;;
  *) next="${1%.frag}" ;;
esac

[[ -f "$dir/$next.frag" ]] || { echo "no such shader: $next" >&2; exit 1; }

# A shader can override the frame rate with a "// fps: N" line near the top.
override=$(head -n 10 "$dir/$next.frag" | grep -m1 -oE '^// *fps: *[0-9]+' | grep -oE '[0-9]+$')
fps="${override:-$fps}"

if command -v shaderbg >/dev/null; then run=(shaderbg)
else run=(nix shell nixpkgs#shaderbg -c shaderbg); fi

pkill -x shaderbg
mkdir -p "$(dirname "$state")"
echo "$next" > "$state"
# One shaderbg per connected output (laptop panel, external monitors, ...).
mapfile -t outputs < <(niri msg outputs | sed -n 's/^Output .*(\(.*\))$/\1/p')
[[ ${#outputs[@]} -eq 0 ]] && { echo "no outputs found via niri msg" >&2; exit 1; }
for output in "${outputs[@]}"; do
  setsid "${run[@]}" --fps "$fps" "$output" "$dir/$next.frag" >/dev/null 2>&1 &
done
echo "$next"
