"""Render a logger session (gnss.ndjson) as a PNG over Esri satellite tiles.

Usage: python render_session_png.py <gnss.ndjson> [out.png] [width_px]

Companion of build_session_map.py for when a static image is needed instead of
the interactive Leaflet page.
"""

import io
import json
import math
import pathlib
import sys
import urllib.request

from PIL import Image, ImageDraw

SRC = pathlib.Path(sys.argv[1])
DST = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else SRC.with_suffix(".png")
WIDTH = int(sys.argv[3]) if len(sys.argv) > 3 else 1400

TILE = 256
MAX_NATIVE_ZOOM = 19
TILE_URL = (
    "https://server.arcgisonline.com/ArcGIS/rest/services/"
    "World_Imagery/MapServer/tile/{z}/{y}/{x}"
)
RAMP = [(0.0, (76, 201, 240)), (0.33, (124, 252, 154)), (0.66, (244, 211, 94)), (1.0, (255, 90, 42))]


def load(path):
    pts = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("lat") and rec.get("lng"):
            pts.append(rec)
    return pts


def project(lat, lng, zoom):
    """Web Mercator pixel coordinates at the given zoom."""
    n = TILE * (2 ** zoom)
    x = (lng + 180.0) / 360.0 * n
    s = math.sin(math.radians(lat))
    y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n
    return x, y


def pick_zoom(lats, lngs, width, height):
    for zoom in range(MAX_NATIVE_ZOOM, 2, -1):
        xs = [project(lat, lng, zoom)[0] for lat, lng in zip(lats, lngs)]
        ys = [project(lat, lng, zoom)[1] for lat, lng in zip(lats, lngs)]
        if max(xs) - min(xs) <= width * 0.88 and max(ys) - min(ys) <= height * 0.88:
            return zoom
    return 3


def fetch_tile(zoom, x, y):
    url = TILE_URL.format(z=zoom, x=x, y=y)
    req = urllib.request.Request(url, headers={"User-Agent": "riderlab-tools"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return Image.open(io.BytesIO(resp.read())).convert("RGB")


def basemap(zoom, left, top, width, height):
    canvas = Image.new("RGB", (width, height), (18, 22, 26))
    x0, y0 = int(left // TILE), int(top // TILE)
    x1, y1 = int((left + width) // TILE), int((top + height) // TILE)
    for tx in range(x0, x1 + 1):
        for ty in range(y0, y1 + 1):
            try:
                tile = fetch_tile(zoom, tx, ty)
            except Exception as exc:  # offline or throttled: keep the dark canvas
                print(f"  tile {zoom}/{tx}/{ty} failed: {exc}")
                continue
            canvas.paste(tile, (int(tx * TILE - left), int(ty * TILE - top)))
    return canvas


def color_for(t):
    t = max(0.0, min(1.0, t))
    for i in range(1, len(RAMP)):
        if t <= RAMP[i][0]:
            lo, hi = RAMP[i - 1], RAMP[i]
            f = (t - lo[0]) / (hi[0] - lo[0] or 1)
            return tuple(int(lo[1][c] + f * (hi[1][c] - lo[1][c])) for c in range(3))
    return RAMP[-1][1]


def main():
    pts = load(SRC)
    if len(pts) < 2:
        raise SystemExit("not enough points")

    lats = [p["lat"] for p in pts]
    lngs = [p["lng"] for p in pts]
    height = int(WIDTH * 0.62)
    zoom = pick_zoom(lats, lngs, WIDTH, height)

    xy = [project(lat, lng, zoom) for lat, lng in zip(lats, lngs)]
    cx = (max(x for x, _ in xy) + min(x for x, _ in xy)) / 2
    cy = (max(y for _, y in xy) + min(y for _, y in xy)) / 2
    left, top = cx - WIDTH / 2, cy - height / 2

    img = basemap(zoom, left, top, WIDTH, height)
    draw = ImageDraw.Draw(img, "RGBA")

    speeds = [p.get("speed_mps", 0) * 3.6 for p in pts]
    vmax = max(speeds) or 1.0
    screen = [(x - left, y - top) for x, y in xy]

    for a, b in zip(screen, screen[1:]):
        draw.line([a, b], fill=(0, 0, 0, 120), width=7)
    for i in range(1, len(screen)):
        draw.line([screen[i - 1], screen[i]], fill=color_for(speeds[i] / vmax), width=4)

    for point, fill in ((screen[0], (124, 252, 154)), (screen[-1], (255, 90, 42))):
        draw.ellipse(
            [point[0] - 8, point[1] - 8, point[0] + 8, point[1] + 8],
            fill=fill, outline=(255, 255, 255), width=2,
        )

    img.save(DST)
    print(f"zoom {zoom} · {len(pts)} pts · vmax {vmax:.1f} km/h -> {DST}")


if __name__ == "__main__":
    main()
