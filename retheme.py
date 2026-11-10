#!/usr/bin/env python3
"""
Recolor an image according to a palette.

CIELAB based pixel modification
  1. Euclidean distance in lab for two nearest colors
  2. blend their a/b by inverse squared distance
  3. move the pixel's a/b toward that blend by TINT (0-1.0)

Usage:
  python retheme.py wallpaper.jpg                   -> wallpaper_themed.png
  python retheme.py wallpaper.jpg -o out.png --tint 0.7
  python retheme.py *.jpg --tint 1                  -> one _themed.png per file

Requires: pip install numpy pillow
"""

# ---------------------------------------------------------------------------
# Palette: any number of #rrggbb colors. Include a spread of lightness
# (darks, mids, lights) plus your accents. Colors are the Marathon theme
# (themes_colorschemes/marathon.md + the Noctalia "Marathon" scheme).
# ---------------------------------------------------------------------------
PALETTE = [
    # backgrounds: almost-oled, flexoki-def, base
    "#010200", "#100F0F", "#1F1F1F",
    # greys / foreground
    "#505050", "#848284", "#A5A6A5", "#DEE3D6", "#FDFFFC",
    # very dark tints          green, cyan, pink, red
    "#404D00", "#004C4D", "#80002D", "#4E000F",
    # muted mid tones          olive-drab, celadon, deep blue, orange, crimson, plum
    "#7F9900", "#33CD82", "#0000CD", "#EB7512", "#DC143C", "#A02F6F",
    # main accents             marathon, cyan, blue, yellow, orange, red, pink, purple
    "#D4FF00", "#00FFFF", "#004FFF", "#F1E42B", "#FFA500", "#FC0434", "#FF347B", "#B33BE4",
    # bright accents           light blue, soft blue
    "#3D7BFF", "#6E9BFF",
]

# Preserve the original hue with 0, squash it to the palette with 1.
TINT = 0.85

import argparse
import sys
from pathlib import Path
import numpy as np
from PIL import Image

CHUNK = 1 << 20  # colors per batch, keeps memory flat on huge images

# sRGB (0-255) to linear RGB to XYZ to Lab (and the reverse on the way out)
# gamma curve   matrix   cube-root formula

_M_RGB2XYZ = np.array([[0.4124, 0.3576, 0.1805],
                       [0.2126, 0.7152, 0.0722],
                       [0.0193, 0.1192, 0.9505]])
_M_XYZ2RGB = np.array([[3.2406, -1.5372, -0.4986],
                       [-0.9689, 1.8758, 0.0415],
                       [0.0557, -0.2040, 1.0570]])
_WHITE = np.array([0.95047, 1.0, 1.08883])  # D65


def rgb_to_lab(rgb):
    """(N,3) sRGB 0-255 -> (N,3) CIELAB."""
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    xyz = (lin @ _M_RGB2XYZ.T) / _WHITE
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[:, 1] - 16,
                     500 * (f[:, 0] - f[:, 1]),
                     200 * (f[:, 1] - f[:, 2])], axis=1)


def lab_to_rgb(lab):
    """(N,3) CIELAB -> (N,3) uint8 sRGB, clamped."""
    fy = (lab[:, 0] + 16) / 116
    f = np.stack([lab[:, 1] / 500 + fy, fy, fy - lab[:, 2] / 200], axis=1)
    f3 = f ** 3
    xyz = np.where(f3 > 0.008856, f3, (f - 16 / 116) / 7.787) * _WHITE
    lin = xyz @ _M_XYZ2RGB.T
    srgb = np.where(lin <= 0.0031308, 12.92 * lin,
                    1.055 * np.power(np.maximum(lin, 0), 1 / 2.4) - 0.055)
    return np.clip(np.floor(srgb * 255 + 0.5), 0, 255).astype(np.uint8)


def hex_to_rgb(h):
    h = h.strip().lstrip("#")
    if len(h) != 6:
        raise ValueError(f"bad color {h!r}, expected #rrggbb")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def remap(rgb, palette_lab, tint):
    """(N,3) sRGB -> (N,3) uint8 recolored toward the palette."""
    lab = rgb_to_lab(rgb.astype(np.float64))
    # squared Lab distance to every palette color, |x|^2 - 2x.p + |p|^2  -> (N,P)
    d = ((lab ** 2).sum(axis=1, keepdims=True) - 2 * lab @ palette_lab.T
         + (palette_lab ** 2).sum(axis=1))
    np.maximum(d, 0, out=d)

    if len(palette_lab) == 1:
        target_ab = np.broadcast_to(palette_lab[0, 1:], (len(lab), 2))
    else:
        two = np.argpartition(d, 1, axis=1)[:, :2]                # 2 nearest
        w = 1.0 / (np.take_along_axis(d, two, axis=1) + 1e-6)     # (N,2)
        ab = palette_lab[two][:, :, 1:]                           # (N,2,2)
        target_ab = (ab * w[:, :, None]).sum(axis=1) / w.sum(axis=1, keepdims=True)

    lab[:, 1:] += (target_ab - lab[:, 1:]) * tint
    return lab_to_rgb(lab)


def retheme_image(img, palette, tint):
    palette_lab = rgb_to_lab(np.array([hex_to_rgb(c) for c in palette], dtype=np.float64))

    has_alpha = img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info)
    img = img.convert("RGBA" if has_alpha else "RGB")
    arr = np.asarray(img)
    h, w, ch = arr.shape
    flat = arr.reshape(-1, ch)

    # Each distinct color only needs to be computed once.
    rgb = flat[:, :3].astype(np.uint32)
    packed = (rgb[:, 0] << 16) | (rgb[:, 1] << 8) | rgb[:, 2]
    uniq, inverse = np.unique(packed, return_inverse=True)
    uniq_rgb = np.stack([(uniq >> 16) & 255, (uniq >> 8) & 255, uniq & 255], axis=1)

    mapped = np.empty((len(uniq), 3), dtype=np.uint8)
    for s in range(0, len(uniq), CHUNK):
        mapped[s:s + CHUNK] = remap(uniq_rgb[s:s + CHUNK], palette_lab, tint)
    out = mapped[inverse.ravel()]

    if has_alpha:
        out = np.concatenate([out, flat[:, 3:4]], axis=1)
    return Image.fromarray(out.reshape(h, w, ch), "RGBA" if has_alpha else "RGB")


def main():
    ap = argparse.ArgumentParser(description="Recolor images toward a palette, keeping lightness.")
    ap.add_argument("inputs", nargs="+", type=Path, help="image file(s)")
    ap.add_argument("-o", "--output", type=Path,
                    help="output file (single input only); default: <name>_themed.png")
    ap.add_argument("-t", "--tint", type=float, default=TINT,
                    help=f"0-1, how far colors move toward the palette (default {TINT})")
    args = ap.parse_args()

    if args.output and len(args.inputs) > 1:
        ap.error("-o/--output only works with a single input")
    if not 0.0 <= args.tint <= 1.0:
        ap.error("--tint must be between 0 and 1")

    for src in args.inputs:
        dst = args.output or src.with_name(f"{src.stem}_themed.png")
        with Image.open(src) as im:
            retheme_image(im, PALETTE, args.tint).save(dst)
        print(f"{src} -> {dst}", file=sys.stderr)


if __name__ == "__main__":
    main()
