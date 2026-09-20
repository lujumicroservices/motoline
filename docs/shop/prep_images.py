"""Compress Runway product shots into web-sized JPEGs for the shop."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tmp" / "runway-preview"
OUT = ROOT / "docs" / "shop" / "img" / "products"
OUT.mkdir(parents=True, exist_ok=True)

# preview name -> (dest stem, max_edge)
JOBS = [
    ("03-look.png", "hero", 1800),
    ("21-look.png", "lifestyle-hat", 1600),
    ("03-look.png", "tee-barredora-1", 1400),
    ("20-look.png", "tee-barredora-2", 1400),
    ("04-look.png", "tee-calle-1", 1400),
    ("19-look.png", "tee-calle-2", 1400),
    ("02-tee.png", "tee-rfr-1", 1400),
    ("06-hat.png", "hat-rl-black-1", 1400),
    ("10-hat.png", "hat-rl-brown-1", 1400),
    ("14-hat.png", "hat-rl-brown-2", 1400),
    ("05-hat.png", "hat-rt-black-1", 1400),
    ("08-hat.png", "hat-rt-black-2", 1400),
    ("18-hat.png", "hat-rt-brown-2", 1400),
    ("16-hat.png", "hat-rt-brown-3", 1400),
    ("15-hat.png", "hat-rt-patch-1", 1400),
    ("09-hat.png", "hat-rt-patch-2", 1400),
    ("17-hat.png", "hat-rt-suede-1", 1400),
    ("13-hat.png", "hat-rt-suede-2", 1400),
]


def save_jpeg(im: Image.Image, dest: Path, quality: int = 82) -> None:
    rgb = ImageOps.exif_transpose(im).convert("RGB")
    dest.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(dest, "JPEG", quality=quality, optimize=True, progressive=True)
    print(f"{dest.name:22} {dest.stat().st_size / 1024:7.0f} KB")


def main() -> None:
    for src_name, stem, edge in JOBS:
        src = SRC / src_name
        im = Image.open(src)
        im.thumbnail((edge, edge), Image.Resampling.LANCZOS)
        save_jpeg(im, OUT / f"{stem}.jpg", 82)
        thumb = im.copy()
        thumb.thumbnail((720, 720), Image.Resampling.LANCZOS)
        save_jpeg(thumb, OUT / f"{stem}-thumb.jpg", 78)


if __name__ == "__main__":
    main()
