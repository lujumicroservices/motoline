# 0.6.2-circuit.3: Metrica icon -> include/BrandIcon.h (RGB565, same symbols kIcon/kIconSm as before).
# Lanczos downscale + light unsharp mask. Source: square wheelie icon (732 px, near-black field); badge = rounded square, radius 18 %.
# Corner tables let the firmware paint outside-the-badge pixels with the theme background (Claro),
# with one anti-aliased edge pixel per row.
import math, numpy as np
from PIL import Image, ImageFilter
SRC = "/workspace/fw062/assets/metrica_icon_wheelie.jpg"; RFRAC = 0.18
src = Image.open(SRC).convert("RGB")
def rgb565(a):
    a = a.astype(np.uint16); return ((a[..., 0] >> 3) << 11) | ((a[..., 1] >> 2) << 5) | (a[..., 2] >> 3)
def make(n):
    im = src.resize((n, n), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=55, threshold=2))
    a = np.asarray(im); R = RFRAC * n; rows = int(math.ceil(R))
    ins, alp = [], []
    for y in range(rows):
        cy = y + 0.5; dy = R - cy
        x = R - math.sqrt(max(R * R - dy * dy, 0)) if dy > 0 else 0.0   # boundary x at this row centre
        xi = int(math.floor(x)); ins.append(xi); alp.append(int(round((1 - (x - xi)) * 255)))  # coverage of pixel xi
    return im, a, rgb565(a), ins, alp
out = ["#pragma once", "// 0.6.2-circuit.3: Metrica wheelie icon (assets/metrica_icon_wheelie.jpg, 732 px) by tools/make_icon_h.py - do not edit.",
       "// RGB565 (push with setSwapBytes(true)). kIcon*Inset[y] = pixels outside the rounded badge on row y (top-left",
       "// corner; mirror for the others), kIcon*Alpha[y] = coverage 0..255 of the first inside pixel.",
       "#include <cstdint>", "#include <pgmspace.h>", "", "namespace riderlab {", ""]
for name, n in (("kIcon", 96), ("kIconSm", 40)):
    im, a, v, ins, alp = make(n); im.save(f"/workspace/fw062/mockups/icon_{n}.png")
    W = "W" if name == "kIcon" else "SmW"; H = W.replace("W", "H")
    out += [f"static constexpr int kIcon{W} = {n};", f"static constexpr int kIcon{H} = {n};",
            f"static constexpr int {name}CornerRows = {len(ins)};",
            f"static const uint8_t {name}Inset[{len(ins)}] = {{{', '.join(map(str, ins))}}};",
            f"static const uint8_t {name}Alpha[{len(alp)}] = {{{', '.join(map(str, alp))}}};",
            f"static const uint16_t {name}[] PROGMEM = {{"]
    flat = v.flatten()
    out += ["  " + ", ".join(f"0x{x:04X}" for x in flat[i:i+12]) + "," for i in range(0, len(flat), 12)]
    out += ["};", ""]
out += ["}  // namespace riderlab", ""]
open("/workspace/fw062/include/BrandIcon.h", "w").write("\n".join(out))
print("ok")
