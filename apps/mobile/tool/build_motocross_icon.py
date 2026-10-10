"""Build the RiderLab Motocross app icon.

The terrain background is drawn here (top-down wireframe relief that fills the
whole square). The rider and the neon jump line are lifted from the generated
source image by colour and composited on top.

Usage: python tool/build_motocross_icon.py
"""

import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "branding" / "motocross"
SRC = OUT_DIR / "rider_source_v3.jpg"

SIZE = 1024
SS = 2  # supersample for anti-aliased lines
BG = np.array([11, 11, 11], dtype=np.float32)

ROW_STEP = 20  # px between relief rows at 1024
COL_STEP = 24
LIFT = 165.0  # px of vertical shift per unit of height


def gauss(x, y, cx, cy, sx, sy, h):
    return h * np.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))


def height(x, y):
    """Motocross terrain in 0..1024 pixel space; ramps sit under the jump line."""
    h = np.zeros_like(x, dtype=np.float32)
    # takeoff and landing under the neon line
    h += gauss(x, y, 320, 760, 70, 45, 0.85)
    h += gauss(x, y, 760, 790, 90, 50, 0.75)
    # tabletop between them, low
    h += gauss(x, y, 540, 840, 170, 40, 0.25)
    # big hills in the back
    h += gauss(x, y, 170, 300, 150, 90, 1.0)
    h += gauss(x, y, 860, 260, 170, 100, 1.1)
    h += gauss(x, y, 500, 180, 130, 70, 0.6)
    # curved berm sweeping around the right side
    ang = np.arctan2(y - 470, x - 650)
    rad = np.hypot(x - 650, y - 470)
    berm = np.exp(-((rad - 300) / 28) ** 2) * np.clip(np.cos(ang - 0.2), 0, 1)
    h += 0.55 * berm.astype(np.float32)
    # whoops row on the left
    for i in range(5):
        h += gauss(x, y, 60 + i * 62, 560 + i * 12, 26, 46, 0.3)
    # rollers at the bottom
    for i in range(4):
        h += gauss(x, y, 200 + i * 190, 970, 70, 35, 0.35)
    # gentle ground noise
    h += 0.06 * np.sin(x / 61.0) * np.cos(y / 47.0)
    h += 0.04 * np.sin((x + y) / 33.0)
    return h


def draw_background():
    """Wireframe cells painted back to front so near hills hide far ones."""
    W = SIZE * SS
    img = Image.new("RGB", (W, W), tuple(int(v) for v in BG))
    d = ImageDraw.Draw(img)
    width = max(1, SS)

    sub = 4  # sub-steps per cell edge so outlines follow the curvature
    xs = np.arange(-80, SIZE + 81, COL_STEP / sub, dtype=np.float32)
    ys = np.arange(-260, SIZE + 260, ROW_STEP / sub, dtype=np.float32)
    gx, gy = np.meshgrid(xs, ys)
    h = height(gx, gy)
    px = gx
    py = gy - LIFT * h
    # light from the top-left: faces turned toward it get a touch brighter
    dhx = np.gradient(h, axis=1) / (COL_STEP / sub) * 60
    dhy = np.gradient(h, axis=0) / (ROW_STEP / sub) * 60
    light = np.clip(0.5 - 0.55 * dhy - 0.25 * dhx, 0.0, 1.0)

    nr, nc = h.shape
    for r0 in range(0, nr - sub, sub):
        for c0 in range(0, nc - sub, sub):
            top = [(px[r0, c], py[r0, c]) for c in range(c0, c0 + sub + 1)]
            right = [(px[r, c0 + sub], py[r, c0 + sub]) for r in range(r0 + 1, r0 + sub + 1)]
            bottom = [(px[r0 + sub, c], py[r0 + sub, c]) for c in range(c0 + sub - 1, c0 - 1, -1)]
            left = [(px[r, c0], py[r, c0]) for r in range(r0 + sub - 1, r0, -1)]
            poly = [(x * SS, y * SS) for x, y in top + right + bottom + left]
            t = float(light[r0 + sub // 2, c0 + sub // 2])
            fill = int(BG[0] + 3 + t * 9)
            line = int(34 + t * 30)
            d.polygon(poly, fill=(fill, fill, fill))
            d.line([(x * SS, y * SS) for x, y in top], fill=(line, line, line), width=width)
            d.line(
                [(x * SS, y * SS) for x, y in [top[0]] + left[::-1] + [bottom[-1]]],
                fill=(int(line * 0.8),) * 3,
                width=width,
            )

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float32)

    # keep it discreet: soft vignette toward the edges
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    r = np.hypot(xx - SIZE / 2, yy - SIZE / 2) / (SIZE * 0.72)
    vig = np.clip(1.15 - r * 0.55, 0.55, 1.0)[..., None]
    arr = BG + (arr - BG) * vig
    return arr


def foreground_masks(src):
    """Rider (hard, holes filled) and neon line (soft glow) from the source."""
    a = src.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    chroma = a.max(axis=2) - a.min(axis=2)

    red = (r > 140) & (r > g + 70) & (r > b + 70)
    rider = Image.fromarray((red * 255).astype(np.uint8), "L")
    rider = rider.filter(ImageFilter.MaxFilter(9))
    ImageDraw.floodfill(rider, (0, 0), 128)
    m = np.asarray(rider).copy()
    m[m == 0] = 255  # enclosed holes = black cut-outs inside the silhouette
    m[m == 128] = 0
    rider = Image.fromarray(m, "L").filter(ImageFilter.MinFilter(9))
    rider = rider.filter(ImageFilter.GaussianBlur(0.8))
    rider_a = np.asarray(rider).astype(np.float32)[..., None] / 255.0

    glow = np.clip((chroma - 22) / 90.0, 0.0, 1.0)[..., None]
    return rider_a, glow


def rounded(img, radius=0.2237):
    mask = Image.new("L", img.size, 0)
    rr = int(img.size[0] * radius)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), rr, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    src = np.asarray(Image.open(SRC).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS))
    bg = draw_background()
    rider_a, glow = foreground_masks(src)
    s = src.astype(np.float32)

    neon = bg + glow * (np.maximum(s, bg) - bg)
    out = neon * (1 - rider_a) + s * rider_a
    icon = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").save(OUT_DIR / "terrain_bg.png")
    icon.save(OUT_DIR / "app_icon_motocross.png")
    icon.resize((512, 512), Image.LANCZOS).save(OUT_DIR / "icon-512_motocross.png")
    rounded(icon).save(OUT_DIR / "preview_rounded.png")

    sheet = Image.new("RGB", (560, 200), (24, 24, 24))
    x = 20
    for px in (180, 96, 48):
        sheet.paste(rounded(icon.resize((px, px), Image.LANCZOS)), (x, (200 - px) // 2), rounded(icon.resize((px, px), Image.LANCZOS)))
        x += px + 40
    sheet.save(OUT_DIR / "preview_sizes.png")
    for p in ("app_icon_motocross.png", "icon-512_motocross.png", "preview_rounded.png", "preview_sizes.png", "terrain_bg.png"):
        print("->", OUT_DIR / p)


if __name__ == "__main__":
    main()
