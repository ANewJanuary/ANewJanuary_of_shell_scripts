#!/usr/bin/env bash
# Sync config between this device and the Syncthing folder (~/Vshrd/config).
#
#   sync-config.sh push   local  -> Vshrd   (~/.config + /etc/nixos -> ~/Vshrd/config)
#   sync-config.sh pull   Vshrd  -> local
#   add --yes to skip the confirmation prompt
#
# Directories are MIRRORED (rsync --delete): files removed on the source side
# are removed on the destination too. Every run shows a dry-run preview first
# and asks before changing anything. ~/Vshrd/config is shared by Syncthing, so
# a push reaches your other devices automatically.
#
# configuration.nix is only copied when the destination hasn't been changed
# since the last sync; otherwise the script stops and shows the diff so you
# can merge by hand (prevents one device wiping another device's changes).
set -euo pipefail

LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}"
SYNC="$HOME/Vshrd/config"
NIX_LOCAL="/etc/nixos/configuration.nix"
NIX_SYNC="$SYNC/configuration.nix"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/sync-config"
NIX_BASE="$STATE/configuration.nix.sha256"   # hash of the last synced version

# Mirrored directories (relative to ~/.config and ~/Vshrd/config)
dirs=(
  kitty swappy nvim yazi zathura fish doom zellij fuzzel helix niri waybar mako
  noctalia
)
# Single files. ssh/: only the config is synced, never keys.
files=(
  ssh/config
  rofimoji.rc
  mimeapps.list
)

usage() {
  echo "usage: $(basename "$0") push|pull [--yes]"
  echo "  push  copy this device's config to $SYNC"
  echo "  pull  copy $SYNC to this device"
}

mode="${1:-}"
yes=0
[[ "${2:-}" == "--yes" ]] && yes=1
case "$mode" in
  push) src="$LOCAL"; dst="$SYNC" ;;
  pull) src="$SYNC";  dst="$LOCAL" ;;
  *) usage; exit 1 ;;
esac
command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }
mkdir -p "$STATE"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | cut -d' ' -f1; else echo "missing"; fi; }

# ---- configuration.nix: decide what to do (no changes yet) ----------------
nix_action="none"   # none | copy | conflict
nix_l=$(sha "$NIX_LOCAL"); nix_s=$(sha "$NIX_SYNC")
nix_b=$(cat "$NIX_BASE" 2>/dev/null || echo "unknown")
if [[ "$nix_l" == "$nix_s" ]]; then
  echo "$nix_l" > "$NIX_BASE"            # already identical, remember it
elif [[ "$mode" == "push" ]]; then
  # safe if the synced copy is still what we last synced (or doesn't exist)
  if [[ "$nix_s" == "missing" || "$nix_s" == "$nix_b" ]]; then nix_action="copy"; else nix_action="conflict"; fi
else
  if [[ "$nix_s" == "missing" ]]; then nix_action="none"
  elif [[ "$nix_l" == "$nix_b" ]]; then nix_action="copy"; else nix_action="conflict"; fi
fi

if [[ "$nix_action" == "conflict" ]]; then
  echo "!! configuration.nix changed on BOTH sides since the last sync."
  echo "   Merge by hand, make $NIX_LOCAL and $NIX_SYNC identical, then rerun."
  echo "   diff (local vs synced):"
  diff -u "$NIX_LOCAL" "$NIX_SYNC" | sed 's/^/   /' || true
  exit 1
fi

# ---- dry run: collect everything that would change -------------------------
preview=""
skipped=()

for d in "${dirs[@]}"; do
  # never mirror from a missing/empty source: --delete would wipe the destination
  if [[ ! -d "$src/$d" ]] || [[ -z "$(ls -A "$src/$d" 2>/dev/null)" ]]; then
    skipped+=("$d/ (missing or empty in $src)"); continue
  fi
  out=$(rsync -a --checksum --delete --itemize-changes --dry-run "$src/$d/" "$dst/$d/" | grep -v '^\.' || true)
  [[ -n "$out" ]] && preview+=$(printf '%s\n' "$out" | sed "s|^\(\S*\) |\1 $d/|")$'\n'
done
for f in "${files[@]}"; do
  if [[ ! -f "$src/$f" ]]; then skipped+=("$f (missing in $src)"); continue; fi
  if ! cmp -s "$src/$f" "$dst/$f"; then preview+=">f       $f"$'\n'; fi
done
if [[ "$nix_action" == "copy" ]]; then
  if [[ "$mode" == "push" ]]; then
    preview+=">f       configuration.nix ($NIX_LOCAL -> $NIX_SYNC)"$'\n'
  else
    preview+=">f       configuration.nix ($NIX_SYNC -> $NIX_LOCAL)"$'\n'
  fi
fi

for s in "${skipped[@]}"; do echo "skip: $s"; done
if [[ -z "$preview" ]]; then
  echo "Everything is already in sync ($mode)."
  exit 0
fi

echo "Planned changes ($mode: $src -> $dst):"
printf '%s' "$preview" | sed 's/^/  /'
total=$(printf '%s' "$preview" | grep -c '' || true)
dels=$(printf '%s' "$preview" | grep -c '^\*deleting' || true)
echo "($total entries, $dels deletions)"

if (( ! yes )); then
  read -r -p "Apply these changes? [y/N] " ans
  [[ "$ans" == [yY]* ]] || { echo "Aborted, nothing changed."; exit 1; }
fi

# ---- apply ------------------------------------------------------------------
for d in "${dirs[@]}"; do
  [[ -d "$src/$d" && -n "$(ls -A "$src/$d" 2>/dev/null)" ]] || continue
  mkdir -p "$dst/$d"
  rsync -a --checksum --delete "$src/$d/" "$dst/$d/"
done
for f in "${files[@]}"; do
  [[ -f "$src/$f" ]] || continue
  mkdir -p "$(dirname "$dst/$f")"
  rsync -a "$src/$f" "$dst/$f"
done
if [[ "$nix_action" == "copy" ]]; then
  if [[ "$mode" == "push" ]]; then
    cp "$NIX_LOCAL" "$NIX_SYNC"
  else
    # /etc/nixos isn't writable as a directory, so overwrite the file in place
    if [[ -w "$NIX_LOCAL" ]]; then cp "$NIX_SYNC" "$NIX_LOCAL"; else sudo cp "$NIX_SYNC" "$NIX_LOCAL"; fi
    echo "configuration.nix updated: run 'sudo nixos-rebuild switch' to apply it."
  fi
  sha "$NIX_LOCAL" > "$NIX_BASE"
fi
echo "Done ($mode)."
