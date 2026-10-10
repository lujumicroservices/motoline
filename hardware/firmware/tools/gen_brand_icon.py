"""Resize the RiderLab app icon to RGB565 C arrays for M5GFX pushImage."""

from pathlib import Path

from PIL import Image

SRC = Path(r"c:\Users\jvald\code\v1\docs\www\_dist\site\icon-512.png")
DST = Path(r"c:\Users\jvald\code\v1\hardware\firmware\include\BrandIcon.h")


def rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def dump(img: Image.Image, name: str) -> str:
    img = img.convert("RGBA")
    bg = Image.new("RGBA", img.size, (0, 0, 0, 255))
    bg.alpha_composite(img)
    rgb = bg.convert("RGB")
    w, h = rgb.size
    pix = list(rgb.getdata())
    lines = [f"static constexpr int {name}W = {w};", f"static constexpr int {name}H = {h};"]
    rows = []
    for i in range(0, len(pix), 12):
        chunk = pix[i : i + 12]
        rows.append("  " + ", ".join(f"0x{rgb565(*p):04X}" for p in chunk) + ",")
    lines.append(f"static const uint16_t {name}[] PROGMEM = {{")
    lines.extend(rows)
    lines.append("};")
    return "\n".join(lines)


src = Image.open(SRC)
parts = [
    dump(src.resize((96, 96), Image.Resampling.LANCZOS), "kIcon"),
    dump(src.resize((40, 40), Image.Resampling.LANCZOS), "kIconSm"),
]
DST.write_text(
    "#pragma once\n"
    "// Generated from docs/www/_dist/site/icon-512.png — do not edit by hand.\n"
    "#include <cstdint>\n#include <pgmspace.h>\n\n"
    "namespace riderlab {\n\n"
    + "\n\n".join(parts)
    + "\n\n}  // namespace riderlab\n",
    encoding="utf-8",
)
print("wrote", DST, "bytes", DST.stat().st_size)
