"""Render a captured logger trace as a standalone Leaflet map.

Usage: python build_gnss_map.py
Reads hardware/captures/m5_gnss_live.json, writes m5_gnss_live.html
"""

import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "captures" / "m5_gnss_live.json"
DST = ROOT / "captures" / "m5_gnss_live.html"


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dphi = p2 - p1
    dl = math.radians(b["lng"] - a["lng"])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def main():
    points = json.loads(SRC.read_text(encoding="utf-8"))
    if not points:
        raise SystemExit("no points captured")

    lat0 = sum(p["lat"] for p in points) / len(points)
    lng0 = sum(p["lng"] for p in points) / len(points)
    # Scatter around the mean is the static-position error of the receiver.
    radii = sorted(haversine({"lat": lat0, "lng": lng0}, p) for p in points)
    cep50 = radii[len(radii) // 2]
    cep95 = radii[min(len(radii) - 1, int(len(radii) * 0.95))]
    hdops = [p["hdop"] for p in points]

    stats = {
        "count": len(points),
        "center": [lat0, lng0],
        "cep50": round(cep50, 2),
        "cep95": round(cep95, 2),
        "spread": round(radii[-1], 2),
        "hdop_min": min(hdops),
        "hdop_max": max(hdops),
        "sats": points[-1]["sats"],
    }

    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>RiderLab logger — traza GNSS</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<style>
  html, body { margin: 0; height: 100%; background: #101214; color: #e8e8e8;
    font: 14px/1.45 system-ui, sans-serif; }
  #map { position: absolute; inset: 0; }
  .panel { position: absolute; z-index: 500; top: 12px; left: 12px; width: 260px;
    background: rgba(16,18,20,.92); border: 1px solid #2c3136; border-radius: 10px;
    padding: 12px 14px; }
  .panel h1 { margin: 0 0 8px; font-size: 15px; }
  .row { display: flex; justify-content: space-between; gap: 10px; }
  .row span:last-child { color: #7CFC9A; font-variant-numeric: tabular-nums; }
  .muted { color: #8b939b; font-size: 12px; margin-top: 8px; }
</style>
</head>
<body>
<div id="map"></div>
<div class="panel">
  <h1>M5 logger — NEO-M9N</h1>
  <div class="row"><span>Puntos</span><span>__COUNT__</span></div>
  <div class="row"><span>Satélites</span><span>__SATS__</span></div>
  <div class="row"><span>HDOP</span><span>__HDOP_MIN__ – __HDOP_MAX__</span></div>
  <div class="row"><span>CEP50</span><span>__CEP50__ m</span></div>
  <div class="row"><span>CEP95</span><span>__CEP95__ m</span></div>
  <div class="row"><span>Dispersión máx</span><span>__SPREAD__ m</span></div>
  <p class="muted">Equipo estático: la nube es el error del receptor, no movimiento.
  El círculo marca CEP95.</p>
</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const PTS = __POINTS__;
const S = __STATS__;

const map = L.map('map', { zoomControl: true }).setView(S.center, 20);
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
  maxZoom: 21, attribution: 'Esri World Imagery'
}).addTo(map);

const latlngs = PTS.map(p => [p.lat, p.lng]);
L.polyline(latlngs, { color: '#4CC9F0', weight: 2, opacity: .75 }).addTo(map);

PTS.forEach((p, i) => {
  L.circleMarker([p.lat, p.lng], {
    radius: 3, color: '#FF5A2A', weight: 1, fillOpacity: .85
  }).addTo(map).bindPopup(
    '#' + (i + 1) + '<br>' + p.lat.toFixed(7) + ', ' + p.lng.toFixed(7) +
    '<br>sats ' + p.sats + ' · hdop ' + p.hdop + '<br>alt ' + p.alt + ' m'
  );
});

L.circle(S.center, { radius: S.cep95, color: '#F4D35E', weight: 1, fill: false,
  dashArray: '4 4' }).addTo(map);
L.circleMarker(S.center, { radius: 5, color: '#fff', weight: 2,
  fillColor: '#F4D35E', fillOpacity: 1 }).addTo(map).bindPopup('Centro promedio');

map.fitBounds(L.polyline(latlngs).getBounds().pad(2.5));
</script>
</body>
</html>
"""

    html = html.replace("__POINTS__", json.dumps(points))
    html = html.replace("__STATS__", json.dumps(stats))
    for key in ("count", "sats", "cep50", "cep95", "spread", "hdop_min", "hdop_max"):
        html = html.replace("__" + key.upper() + "__", str(stats[key]))

    DST.write_text(html, encoding="utf-8")
    print(json.dumps(stats, indent=2))
    print("->", DST)


if __name__ == "__main__":
    main()
