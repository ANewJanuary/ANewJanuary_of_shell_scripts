#!/usr/bin/env python3
"""

  1. Shrink   :: downsample oversized bitmaps (cough cough DBM)
  2. Margins  :: pad every page with real blank space for doodles
  3. Invert   :: flip colours for dark mode (optional) with blend modes

  Examples:
    pdfprep slides.pdf                    # 8cm notes column on the right
    pdfprep slides.pdf --right-cm 12      # wider column
    pdfprep slides.pdf --margin-cm 5      # 5cm on every side instead
    pdfprep .                             # every PDF in the current directory
    pdfprep lectures/ --no-invert --dpi 120
    pdfprep a.pdf b.pdf --outdir ~/prepped

Requires: pypdf, Pillow. Ghostscript ('gs') is used for shrinking when
available and gives better results; otherwise a pure-Python fallback runs.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

try:
    from pypdf import PdfReader, PdfWriter, Transformation
    from pypdf.generic import (
        ArrayObject,
        DecodedStreamObject,
        DictionaryObject,
        FloatObject,
        NameObject,
    )
except ImportError:
    sys.exit("Error: pypdf is not installed.  pip install pypdf Pillow")


CM_TO_PT = 28.3465  # 1 cm in PDF points


# --------------------------------------------------------------------------
# colour handling
# --------------------------------------------------------------------------

NAMED_COLOURS = {
    "black": "#000000",
    "dark": "#1e1e1e",
    "darkgray": "#2b2b2b",
    "darkgrey": "#2b2b2b",
    "nord": "#2e3440",
    "dracula": "#282a36",
    "gruvbox": "#282828",
    "solarized": "#002b36",
    "sepia": "#3a3228",
    "navy": "#0f1419",
}


def parse_colour(value: str) -> tuple[float, float, float]:
    """Accepts '#rrggbb', '#rgb', 'rrggbb', or a name from NAMED_COLOURS."""
    v = value.strip().lower()
    v = NAMED_COLOURS.get(v, v)
    v = v.lstrip("#")

    if len(v) == 3:
        v = "".join(c * 2 for c in v)
    if len(v) != 6:
        raise argparse.ArgumentTypeError(
            f"bad colour {value!r}: use #rrggbb, #rgb, or one of "
            + ", ".join(sorted(NAMED_COLOURS))
        )
    try:
        r, g, b = (int(v[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    except ValueError:
        raise argparse.ArgumentTypeError(f"bad colour {value!r}")
    return r, g, b


# --------------------------------------------------------------------------
# step 1 -- shrink bitmaps
# --------------------------------------------------------------------------


def shrink_with_ghostscript(src: Path, dst: Path, dpi: int, quality: int) -> bool:
    """Downsample images via Ghostscript. Returns False if gs is unavailable."""
    gs = shutil.which("gs")
    if not gs:
        return False

    cmd = [
        gs,
        "-sDEVICE=pdfwrite",
        "-dCompatibilityLevel=1.7",  # 1.4+ required for blend modes later
        "-dNOPAUSE",
        "-dBATCH",
        "-dQUIET",
        "-dDetectDuplicateImages=true",
        # colour images
        "-dDownsampleColorImages=true",
        "-dColorImageDownsampleType=/Bicubic",
        f"-dColorImageResolution={dpi}",
        "-dAutoFilterColorImages=false",
        "-dColorImageFilter=/DCTEncode",
        # greyscale images
        "-dDownsampleGrayImages=true",
        "-dGrayImageDownsampleType=/Bicubic",
        f"-dGrayImageResolution={dpi}",
        "-dAutoFilterGrayImages=false",
        "-dGrayImageFilter=/DCTEncode",
        # 1-bit images
        "-dDownsampleMonoImages=true",
        "-dMonoImageDownsampleType=/Subsample",
        f"-dMonoImageResolution={dpi * 4}",
        f"-dJPEGQ={quality}",
        f"-sOutputFile={dst}",
        str(src),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(
            f"  ! ghostscript failed ({e.returncode}), falling back to Python",
            file=sys.stderr,
        )
        return False
    return dst.exists() and dst.stat().st_size > 0


def shrink_with_python(src: Path, dst: Path, max_px: int, quality: int) -> None:
    """Pure-Python fallback: re-encode oversized embedded bitmaps via Pillow."""
    try:
        from PIL import Image
    except ImportError:
        shutil.copyfile(src, dst)
        print("  ! Pillow missing, skipping shrink", file=sys.stderr)
        return

    reader = PdfReader(str(src))
    writer = PdfWriter(clone_from=reader)

    touched = 0
    for page in writer.pages:
        try:
            images = list(page.images)
        except Exception:
            continue
        for img in images:
            try:
                pil = img.image
                if pil is None:
                    continue
                w, h = pil.size
                if max(w, h) <= max_px:
                    continue
                scale = max_px / max(w, h)
                new_size = (max(1, int(w * scale)), max(1, int(h * scale)))
                resized = pil.resize(new_size, Image.LANCZOS)
                if resized.mode not in ("RGB", "L"):
                    resized = resized.convert("RGB")
                img.replace(resized, quality=quality, optimize=True)
                touched += 1
            except Exception:
                continue  # leave anything we can't safely rewrite alone

    with open(dst, "wb") as fh:
        writer.write(fh)
    if touched:
        print(f"  · resampled {touched} image(s) with Pillow")


# --------------------------------------------------------------------------
# step 2 + 3 -- margins and inversion
# --------------------------------------------------------------------------


def _append_content(page, writer: PdfWriter, ops: str) -> None:
    """Append a raw content stream to a page."""
    stream = DecodedStreamObject()
    stream.set_data(ops.encode("latin-1"))
    ref = writer._add_object(stream)

    existing = page.raw_get("/Contents") if "/Contents" in page else None
    if existing is None:
        page[NameObject("/Contents")] = ArrayObject([ref])
        return

    resolved = existing.get_object()
    if isinstance(resolved, ArrayObject):
        resolved.append(ref)
        page[NameObject("/Contents")] = (
            existing if hasattr(existing, "idnum") else resolved
        )
    else:
        page[NameObject("/Contents")] = ArrayObject([existing, ref])


def _register_blend_states(page, writer: PdfWriter) -> None:
    """Add /GSinv (Difference) and /GSbg (Lighten) to the page's ExtGState."""
    if "/Resources" not in page:
        page[NameObject("/Resources")] = DictionaryObject()
    resources = page[NameObject("/Resources")]

    if "/ExtGState" not in resources:
        resources[NameObject("/ExtGState")] = DictionaryObject()
    egs = resources[NameObject("/ExtGState")]

    for name, mode in (("/GSinv", "/Difference"), ("/GSbg", "/Lighten")):
        gs_dict = DictionaryObject()
        gs_dict[NameObject("/Type")] = NameObject("/ExtGState")
        gs_dict[NameObject("/BM")] = NameObject(mode)
        gs_dict[NameObject("/CA")] = FloatObject(1.0)  # fully opaque stroke
        gs_dict[NameObject("/ca")] = FloatObject(1.0)  # fully opaque fill
        egs[NameObject(name)] = writer._add_object(gs_dict)


@dataclass
class Margins:
    top: float
    right: float
    bottom: float
    left: float

    @property
    def extra_w(self) -> float:
        return self.left + self.right

    @property
    def extra_h(self) -> float:
        return self.top + self.bottom


def build(
    src: Path,
    dst: Path,
    margins: Margins,
    invert: bool,
    bg: tuple[float, float, float],
) -> None:
    reader = PdfReader(str(src))
    writer = PdfWriter()

    for page in reader.pages:
        ow = float(page.mediabox.width)
        oh = float(page.mediabox.height)
        nw = ow + margins.extra_w
        nh = oh + margins.extra_h

        new_page = writer.add_blank_page(width=nw, height=nh)

        # opaque white base, so margins blend predictably
        _append_content(new_page, writer, f"q 1 1 1 rg 0 0 {nw:.2f} {nh:.2f} re f Q\n")

        # original content, offset into the padded page
        new_page.merge_transformed_page(
            page, Transformation().translate(margins.left, margins.bottom)
        )

        if invert:
            _register_blend_states(new_page, writer)
            r, g, b = bg
            _append_content(
                new_page,
                writer,
                # 1. Difference against white  -> full colour inversion
                f"q /GSinv gs 1 1 1 rg 0 0 {nw:.2f} {nh:.2f} re f Q\n"
                # 2. Lighten toward bg colour  -> black becomes your background
                f"q /GSbg gs {r:.4f} {g:.4f} {b:.4f} rg "
                f"0 0 {nw:.2f} {nh:.2f} re f Q\n",
            )

    try:
        writer.compress_identical_objects()
    except Exception:
        pass

    with open(dst, "wb") as fh:
        writer.write(fh)


# --------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------


def collect_inputs(raw: list[str]) -> list[Path]:
    """Resolve args (relative to CWD) into a flat list of absolute PDF paths."""
    out: list[Path] = []
    for item in raw:
        p = Path(item).expanduser().resolve()
        if p.is_dir():
            out.extend(
                sorted(f for f in p.iterdir() if f.suffix.lower() == ".pdf")
            )
        elif p.is_file():
            out.append(p)
        else:
            print(f"! skipping {p} (not found)", file=sys.stderr)
    # drop files we previously generated, so re-runs don't stack suffixes
    return [p for p in out if not p.stem.endswith("_prepped")]


def human(n: int) -> str:
    return f"{n / 1_000_000:.1f} MB"


def main() -> None:
    ap = argparse.ArgumentParser(
        prog="pdfprep",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("inputs", nargs="+", help="PDF files and/or directories")
    ap.add_argument(
        "-o",
        "--output",
        default=None,
        help="output file (single input only; default <name>_prepped.pdf)",
    )
    ap.add_argument("--outdir", default=None, help="write results into this directory")

    g = ap.add_argument_group("margins")
    g.add_argument(
        "--margin-cm",
        type=float,
        default=None,
        help="apply this margin to ALL sides (default: 8cm on the right only)",
    )
    for side in ("top", "right", "bottom", "left"):
        g.add_argument(f"--{side}-cm", type=float, default=None, help=f"override {side}")
    g.add_argument(
        "--no-margins", action="store_true", help="don't pad the pages at all"
    )

    g = ap.add_argument_group("colour")
    g.add_argument(
        "--no-invert", action="store_true", help="keep original colours"
    )
    g.add_argument(
        "--bg",
        type=parse_colour,
        default="#1e1e1e",
        metavar="COLOUR",
        help="background after inversion: #rrggbb or a name "
        "(" + ", ".join(sorted(NAMED_COLOURS)) + "); default #1e1e1e",
    )

    g = ap.add_argument_group("performance")
    g.add_argument("--dpi", type=int, default=150, help="image resolution (default 150)")
    g.add_argument(
        "--jpeg-quality", type=int, default=80, help="JPEG quality 1-100 (default 80)"
    )
    g.add_argument("--no-shrink", action="store_true", help="skip image downsampling")

    args = ap.parse_args()

    # --bg may still be the default string if the user didn't pass the flag
    bg = args.bg if isinstance(args.bg, tuple) else parse_colour(args.bg)

    files = collect_inputs(args.inputs)
    if not files:
        sys.exit("No PDFs to process.")
    if args.output and len(files) > 1:
        sys.exit("An explicit output path only works with a single input file.")

    # Default shape: a tall notes column on the right, nothing elsewhere.
    # --margin-cm N overrides that and applies N to every side.
    # Individual --<side>-cm flags always win over both.
    if args.no_margins:
        base = right_default = 0.0
    elif args.margin_cm is not None:
        base = right_default = args.margin_cm
    else:
        base, right_default = 0.0, 8.0

    def pick(value: float | None, fallback: float) -> float:
        return (fallback if value is None else value) * CM_TO_PT

    margins = Margins(
        top=pick(args.top_cm, base),
        right=pick(args.right_cm, right_default),
        bottom=pick(args.bottom_cm, base),
        left=pick(args.left_cm, base),
    )
    if args.no_margins:
        margins = Margins(0.0, 0.0, 0.0, 0.0)

    outdir = Path(args.outdir).expanduser().resolve() if args.outdir else None
    if outdir:
        outdir.mkdir(parents=True, exist_ok=True)

    max_px = int(args.dpi * 11.7)  # ~long edge of A4 at the target dpi

    for src in files:
        if args.output:
            dst = Path(args.output).expanduser().resolve()
        else:
            target_dir = outdir or src.parent
            dst = target_dir / f"{src.stem}_prepped.pdf"
        dst.parent.mkdir(parents=True, exist_ok=True)

        print(f"{src.name}  ({human(src.stat().st_size)})")

        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp) / "stage.pdf"

            if args.no_shrink:
                shutil.copyfile(src, stage)
            else:
                if not shrink_with_ghostscript(
                    src, stage, args.dpi, args.jpeg_quality
                ):
                    shrink_with_python(src, stage, max_px, args.jpeg_quality)
                print(f"  · shrunk to {human(stage.stat().st_size)}")

            build(stage, dst, margins, not args.no_invert, bg)

        bits = []
        if not args.no_margins:
            sides = {
                "T": margins.top,
                "R": margins.right,
                "B": margins.bottom,
                "L": margins.left,
            }
            used = [f"{k}{v / CM_TO_PT:g}cm" for k, v in sides.items() if v > 0]
            bits.append("margins " + (" ".join(used) if used else "none"))
        if not args.no_invert:
            bits.append("inverted")
        print(f"  -> {dst}  ({human(dst.stat().st_size)}) [{', '.join(bits) or 'plain'}]")


if __name__ == "__main__":
    main()
