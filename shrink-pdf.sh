#!/usr/bin/env bash
set -euo pipefail

# Shrinks every PDF in the current directory using Ghostscript.
# Compressed files are written to a "compressed/" subfolder so
# originals are never touched or overwritten.
#
# Usage:
#   ./shrink-pdfs.sh            # default quality: /ebook (150 dpi-ish, good for slides)
#   ./shrink-pdfs.sh screen     # smallest, lowest quality (~72 dpi)
#   ./shrink-pdfs.sh ebook      # good balance (default)
#   ./shrink-pdfs.sh printer    # higher quality, bigger files (~300 dpi)
#   ./shrink-pdfs.sh prepress   # highest quality, least compression

if ! command -v gs >/dev/null 2>&1; then
  echo "Error: ghostscript ('gs') not found on PATH." >&2
  echo "On NixOS/nix, run this script inside a shell that has it, e.g.:" >&2
  echo "  nix-shell -p ghostscript --run ./shrink-pdfs.sh" >&2
  exit 1
fi

quality="${1:-ebook}"
case "$quality" in
  screen|ebook|printer|prepress) ;;
  *)
    echo "Error: unknown quality '$quality'. Use: screen, ebook, printer, or prepress." >&2
    exit 1
    ;;
esac

outdir="compressed"
mkdir -p "$outdir"

shopt -s nullglob nocaseglob
pdfs=(*.pdf)
shopt -u nocaseglob

if [ ${#pdfs[@]} -eq 0 ]; then
  echo "No PDF files found in $(pwd)."
  exit 0
fi

echo "Compressing ${#pdfs[@]} PDF(s) with quality='$quality' -> ./$outdir/"
echo

for f in "${pdfs[@]}"; do
  out="$outdir/$f"
  before=$(du -h "$f" | cut -f1)

  gs -sDEVICE=pdfwrite \
     -dCompatibilityLevel=1.4 \
     -dPDFSETTINGS="/$quality" \
     -dNOPAUSE -dBATCH -dQUIET \
     -sOutputFile="$out" \
     "$f"

  after=$(du -h "$out" | cut -f1)
  echo "  $f: $before -> $after"
done

echo
echo "Done. Compressed files are in ./$outdir/"
echo "Originals were left untouched."
