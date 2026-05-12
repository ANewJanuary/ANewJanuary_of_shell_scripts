#!/usr/bin/env bash
set -euo pipefail

SOCKET="/tmp/nvimsocket"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <file> [line] [col]" >&2
  exit 1
fi

FILE="$1"
LINE="${2:-}"
COL="${3:-}"

server_alive() {
  [[ -S "$SOCKET" ]]
}

start_neovide() {
  rm -f "$SOCKET"
  neovide -- --listen "$SOCKET" >/dev/null 2>&1 &

  for _ in $(seq 1 50); do
    if server_alive; then
      return 0
    fi
    sleep 0.1
  done

  echo "failed to start neovide listening on $SOCKET" >&2
  exit 1
}

open_target() {
  if [[ -n "$LINE" && -n "$COL" ]]; then
    nvim --server "$SOCKET" --remote "+call cursor($LINE,$COL)" "$FILE"
  elif [[ -n "$LINE" ]]; then
    nvim --server "$SOCKET" --remote "+$LINE" "$FILE"
  else
    nvim --server "$SOCKET" --remote "$FILE"
  fi
}

if ! server_alive; then
  start_neovide
fi

open_target
