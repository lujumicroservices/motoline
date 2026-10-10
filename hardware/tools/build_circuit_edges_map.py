"""Map logger edge passes: first two left, last two right."""

import json
import math
import pathlib

HERE = pathlib.Path(r"c:\Users\jvald\code\v1\hardware\captures")
SESS = HERE / "sessions"

PASSES = [
    {
        "id": "3876d0c9-b70f-0bc2-c92d-d0c92df402be",
        "label": "1 · izquierdo",
        "side": "left",
        "color": "#ea580c",
    },
    {
        "id": "3876d0c9-00fb-119e-c92d-d0c92df4828f",
        "label": "2 · izquierdo",
        "side": "left",
        "color": "#f59e0b",
    },
    {
        "id": "3876d0c9-ded0-180a-c92d-d0c92df427a5",
        "label": "3 · derecho",
        "side": "right",
        "color": "#2563eb",
    },
    {
        "id": "3876d0c9-a684-1d22-c92d-d0c92df4756a",
        "label": "4 · derecho",
        "side": "right",
        "color": "#06b6d4",
    },
]


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dphi = p2 - p1
    dl = math.radians(b[1] - a[1])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def load(sid):
    uniq = []
    raw_n = 0
    for line in (SESS / f"{sid}__gnss.ndjson").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        rec = json.loads(line)
        raw_n += 1
        if not rec.get("lat") or not rec.get("lng"):
            continue
        if uniq and uniq[-1][0] == rec["lat"] and uniq[-1][1] == rec["lng"]:
            continue
        uniq.append([rec["lat"], rec["lng"]])
    dist = sum(haversine(a, b) for a, b in zip(uniq, uniq[1:]))
    return uniq, dist, raw_n


tracks = []
for p in PASSES:
    pts, dist, raw_n = load(p["id"])
    tracks.append({**p, "pts": pts, "m": round(dist, 1), "n": len(pts), "raw": raw_n})

left = [t for t in tracks if t["side"] == "left"]
right = [t for t in tracks if t["side"] == "right"]
left_pts = [p for t in left for p in t["pts"]]
right_pts = [p for t in right for p in t["pts"]]
widths = []
if left_pts and right_pts:
    step = max(1, len(left_pts) // 50)
    for p in left_pts[::step]:
        widths.append(min(haversine(p, q) for q in right_pts))
width_med = sorted(widths)[len(widths) // 2] if widths else 0

payload = json.dumps(
    {"tracks": tracks, "width_m": round(width_med, 1)}, separators=(",", ":")
)
html = f"""<!DOCTYPE html>
<html lang="es"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Circuito — bordes izquierdo y derecho</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
 html,body,#map{{margin:0;height:100%}}
 .legend{{background:#111;color:#eee;padding:8px 10px;border-radius:8px;font:13px/1.5 system-ui}}
 .sw{{display:inline-block;width:18px;height:3px;vertical-align:middle;margin-right:6px}}
</style></head><body>
<div id="map"></div>
<script>
const D = {payload};
const map = L.map('map');
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{{z}}/{{y}}/{{x}}',
  {{maxZoom:19, attribution:'Esri'}}).addTo(map);
const bounds = [];
D.tracks.forEach(t => {{
  if (!t.pts.length) return;
  const line = L.polyline(t.pts, {{color:t.color, weight:4, opacity:.92}}).addTo(map);
  line.bindPopup(t.label + '<br>' + t.n + ' pts · ' + t.m + ' m');
  L.circleMarker(t.pts[0], {{radius:6, color:'#fff', fillColor:t.color, fillOpacity:1, weight:1}})
    .addTo(map).bindPopup('inicio ' + t.label);
  L.circleMarker(t.pts[t.pts.length-1], {{radius:6, color:'#fff', fillColor:'#111', fillOpacity:1, weight:1}})
    .addTo(map).bindPopup('fin ' + t.label);
  bounds.push(...t.pts);
}});
map.fitBounds(bounds, {{padding:[24,24]}});
const legend = L.control({{position:'bottomleft'}});
legend.onAdd = () => {{
  const el = L.DomUtil.create('div','legend');
  el.innerHTML = D.tracks.map(t =>
    `<span class="sw" style="background:${{t.color}}"></span>${{t.label}} · ${{t.n}} pts · ${{t.m}} m<br>`
  ).join('') + `ancho tipico ~ ${{D.width_m}} m`;
  return el;
}};
legend.addTo(map);
</script></body></html>
"""
out = HERE / "circuit_edges.html"
out.write_text(html, encoding="utf-8")
print("width_med", width_med)
print("->", out)
for t in tracks:
    print(t["label"], "raw", t["raw"], "uniq", t["n"], t["m"], "m")
