#!/usr/bin/env bash
# Headless preview: render a shader to PNG (half size) and print GPU ms/frame.
#   preview.sh <shader.frag> <out.png> [t1,t2,...] [WxH]
# Multiple times write out_<t>.png. Default: t=10, 2560x1440.
here="$(cd "$(dirname "$0")" && pwd)"
exec nix shell --impure --expr 'with import <nixpkgs> {}; python3.withPackages (p: [p.moderngl p.pillow p.numpy])' \
  -c python3 "$here/render.py" "$@"
