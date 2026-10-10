"""Render a logger session (gnss.ndjson) as a standalone Leaflet map.

Usage: python build_session_map.py <gnss.ndjson> [out.html]
"""

import json
import math
import pathlib
import sys

SRC = pathlib.Path(sys.argv[1])
DST = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else SRC.with_suffix(".html")


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dphi = p2 - p1
    dl = math.radians(b["lng"] - a["lng"])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def load(path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("lat") and rec.get("lng"):
            rows.append(rec)
    return rows


def dedupe(rows):
    """The logger samples faster than the 1 Hz receiver, so drop repeats."""
    out = []
    for r in rows:
        if out and out[-1]["lat"] == r["lat"] and out[-1]["lng"] == r["lng"]:
            continue
        out.append(r)
    return out


def main():
    raw = load(SRC)
    pts = dedupe(raw)
    if len(pts) < 2:
        raise SystemExit("not enough points")

    dist = 0.0
    hops = []
    for a, b in zip(pts, pts[1:]):
        d = haversine(a, b)
        dist += d
        hops.append(d)

    speeds = [p.get("speed_mps", 0) * 3.6 for p in pts]
    dur_s = (pts[-1]["t_us"] - pts[0]["t_us"]) / 1e6
    lats = [p["lat"] for p in pts]
    lngs = [p["lng"] for p in pts]

    stats = {
        "samples": len(raw),
        "points": len(pts),
        "km": round(dist / 1000, 3),
        "minutes": round(dur_s / 60, 1),
        "vmax": round(max(speeds), 1),
        "vavg": round(sum(speeds) / len(speeds), 1),
        "gap_avg": round(sum(hops) / len(hops), 1),
        "gap_max": round(max(hops), 1),
        "sats_min": min(p.get("sats", 0) for p in pts),
        "sats_max": max(p.get("sats", 0) for p in pts),
        "center": [sum(lats) / len(lats), sum(lngs) / len(lngs)],
    }

    track = [
        [round(p["lat"], 7), round(p["lng"], 7), round(p.get("speed_mps", 0) * 3.6, 1),
         p.get("sats", 0), p.get("hdop", 0)]
        for p in pts
    ]

    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>RiderLab logger — recorrido</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<style>
  html, body { margin: 0; height: 100%; background: #101214; color: #e8e8e8;
    font: 14px/1.45 system-ui, sans-serif; }
  #map { position: absolute; inset: 0; }
  .panel { position: absolute; z-index: 500; top: 12px; left: 12px; width: 250px;
    background: rgba(16,18,20,.93); border: 1px solid #2c3136; border-radius: 10px;
    padding: 12px 14px; }
  .panel h1 { margin: 0 0 8px; font-size: 15px; }
  .row { display: flex; justify-content: space-between; gap: 10px; }
  .row span:last-child { color: #7CFC9A; font-variant-numeric: tabular-nums; }
  .muted { color: #8b939b; font-size: 12px; margin-top: 8px; }
  .legend { position: absolute; z-index: 500; bottom: 16px; left: 12px;
    background: rgba(16,18,20,.93); border: 1px solid #2c3136; border-radius: 8px;
    padding: 8px 10px; font-size: 12px; }
  .bar { height: 8px; width: 160px; border-radius: 4px; margin: 4px 0;
    background: linear-gradient(90deg,#4CC9F0,#7CFC9A,#F4D35E,#FF5A2A); }
</style>
</head>
<body>
<div id="map"></div>
<div class="panel">
  <h1>Recorrido del piloto</h1>
  <div class="row"><span>Distancia</span><span>__KM__ km</span></div>
  <div class="row"><span>Duración</span><span>__MINUTES__ min</span></div>
  <div class="row"><span>Vel. máx</span><span>__VMAX__ km/h</span></div>
  <div class="row"><span>Vel. media</span><span>__VAVG__ km/h</span></div>
  <div class="row"><span>Puntos GPS</span><span>__POINTS__</span></div>
  <div class="row"><span>Satélites</span><span>__SATS_MIN__ – __SATS_MAX__</span></div>
  <div class="row"><span>Separación</span><span>__GAP_AVG__ m</span></div>
  <p class="muted">__SAMPLES__ muestras crudas a 10 Hz sobre un receptor de 1 Hz:
  quedan __POINTS__ posiciones únicas, ~__GAP_AVG__ m entre puntos.</p>
</div>
<div class="legend">Velocidad<div class="bar"></div>0 → __VMAX__ km/h</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const T = __TRACK__;
const S = __STATS__;

const map = L.map('map').setView(S.center, 16);
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
  maxZoom: 21, attribution: 'Esri World Imagery'
}).addTo(map);

function colorFor(kmh) {
  const t = Math.max(0, Math.min(1, kmh / Math.max(1, S.vmax)));
  const stops = [[0,'#4CC9F0'],[0.33,'#7CFC9A'],[0.66,'#F4D35E'],[1,'#FF5A2A']];
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) return stops[i][1];
  }
  return stops[stops.length - 1][1];
}

// One short segment per hop keeps the speed gradient readable.
for (let i = 1; i < T.length; i++) {
  L.polyline([[T[i-1][0], T[i-1][1]], [T[i][0], T[i][1]]], {
    color: colorFor(T[i][2]), weight: 4, opacity: .9
  }).addTo(map);
}

const first = T[0], last = T[T.length - 1];
L.circleMarker([first[0], first[1]], { radius: 7, color: '#fff', weight: 2,
  fillColor: '#7CFC9A', fillOpacity: 1 }).addTo(map).bindPopup('Inicio');
L.circleMarker([last[0], last[1]], { radius: 7, color: '#fff', weight: 2,
  fillColor: '#FF5A2A', fillOpacity: 1 }).addTo(map).bindPopup('Fin');

const bounds = L.latLngBounds(T.map(p => [p[0], p[1]]));
map.fitBounds(bounds.pad(0.08));

map.on('click', e => {
  let best = null, bestD = Infinity;
  T.forEach((p, i) => {
    const d = map.distance(e.latlng, L.latLng(p[0], p[1]));
    if (d < bestD) { bestD = d; best = i; }
  });
  if (best !== null && bestD < 40) {
    const p = T[best];
    L.popup().setLatLng([p[0], p[1]]).setContent(
      '#' + (best + 1) + '<br>' + p[2] + ' km/h<br>sats ' + p[3] + ' · hdop ' + p[4]
    ).openOn(map);
  }
});
</script>
</body>
</html>
"""

    html = html.replace("__TRACK__", json.dumps(track))
    html = html.replace("__STATS__", json.dumps(stats))
    for key, value in stats.items():
        html = html.replace("__" + key.upper() + "__", str(value))

    DST.write_text(html, encoding="utf-8")
    print(json.dumps(stats, indent=2))
    print("->", DST)


if __name__ == "__main__":
    main()
