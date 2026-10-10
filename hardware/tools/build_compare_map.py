"""Overlay two logger sessions on one Leaflet map and measure their separation.

Usage: python build_compare_map.py <a.ndjson> <b.ndjson> [out.html] [--names A,B]

Samples are paired by GNSS utc_ms, so the separation is between both loggers
at the same instant (useful when they rode together on the same bike/route).
"""

import json
import pathlib
import sys

from build_session_map import dedupe, haversine, load

args = [a for a in sys.argv[1:] if not a.startswith("--")]
SRC_A, SRC_B = pathlib.Path(args[0]), pathlib.Path(args[1])
DST = pathlib.Path(args[2]) if len(args) > 2 else SRC_A.parent / "compare.html"
NAMES = ["A", "B"]
if "--names" in sys.argv:
    NAMES = sys.argv[sys.argv.index("--names") + 1].split(",")[:2]


def summarize(pts):
    dist = sum(haversine(a, b) for a, b in zip(pts, pts[1:]))
    speeds = [p.get("speed_mps", 0) * 3.6 for p in pts]
    return {
        "points": len(pts),
        "km": round(dist / 1000, 3),
        "minutes": round((pts[-1]["t_us"] - pts[0]["t_us"]) / 6e7, 1),
        "vmax": round(max(speeds), 1),
        "acc": round(sorted(p.get("acc_m", 0) for p in pts)[len(pts) // 2], 2),
    }


def pct(vals, q):
    vals = sorted(vals)
    return round(vals[min(len(vals) - 1, int(q * len(vals)))], 2)


def main():
    a, b = dedupe(load(SRC_A)), dedupe(load(SRC_B))
    by_t = {p["utc_ms"]: p for p in b if "utc_ms" in p}
    pairs = [(p, by_t[p["utc_ms"]]) for p in a if p.get("utc_ms") in by_t]
    seps = [haversine(p, q) for p, q in pairs]

    sep = {
        "pairs": len(pairs),
        "p50": pct(seps, 0.5) if seps else None,
        "p90": pct(seps, 0.9) if seps else None,
        "max": round(max(seps), 2) if seps else None,
    }
    # Every 5th paired sample keeps the separation layer light.
    links = [[round(p["lat"], 7), round(p["lng"], 7), round(q["lat"], 7), round(q["lng"], 7),
              round(d, 2)] for i, ((p, q), d) in enumerate(zip(pairs, seps)) if i % 5 == 0]

    def track(pts):
        return [[round(p["lat"], 7), round(p["lng"], 7), round(p.get("speed_mps", 0) * 3.6, 1),
                 p.get("sats", 0), p.get("acc_m", 0)] for p in pts]

    data = {
        "names": NAMES,
        "tracks": [track(a), track(b)],
        "stats": [summarize(a), summarize(b)],
        "sep": sep,
        "links": links,
    }

    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>RiderLab — comparación de 2 loggers</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<style>
  html, body { margin: 0; height: 100%; background: #101214; color: #e8e8e8;
    font: 14px/1.45 system-ui, sans-serif; }
  #map { position: absolute; inset: 0; }
  .panel { position: absolute; z-index: 500; top: 12px; left: 12px; width: 290px;
    background: rgba(16,18,20,.93); border: 1px solid #2c3136; border-radius: 10px;
    padding: 12px 14px; }
  .panel h1 { margin: 0 0 8px; font-size: 15px; }
  table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
  td { padding: 2px 0; } td:not(:first-child) { text-align: right; }
  .sw { display: inline-block; width: 12px; height: 4px; border-radius: 2px; margin-right: 6px;
    vertical-align: middle; }
  label { display: block; margin-top: 4px; cursor: pointer; }
  .muted { color: #8b939b; font-size: 12px; margin-top: 8px; }
  .hi { color: #7CFC9A; }
</style>
</head>
<body>
<div id="map"></div>
<div class="panel">
  <h1>2 loggers, misma rodada</h1>
  <table>
    <tr><td></td><td id="hA"></td><td id="hB"></td></tr>
    <tr><td>Distancia</td><td id="kmA"></td><td id="kmB"></td></tr>
    <tr><td>Duración</td><td id="minA"></td><td id="minB"></td></tr>
    <tr><td>Vel. máx</td><td id="vA"></td><td id="vB"></td></tr>
    <tr><td>Puntos</td><td id="pA"></td><td id="pB"></td></tr>
    <tr><td>Precisión (med.)</td><td id="aA"></td><td id="aB"></td></tr>
  </table>
  <p style="margin:10px 0 4px"><b>Separación entre loggers</b> (mismo instante GPS)</p>
  <table>
    <tr><td>Mediana</td><td class="hi" id="s50"></td></tr>
    <tr><td>90 %</td><td class="hi" id="s90"></td></tr>
    <tr><td>Máxima</td><td class="hi" id="smax"></td></tr>
    <tr><td>Pares comparados</td><td id="sn"></td></tr>
  </table>
  <label><input type="checkbox" id="tA" checked> <span class="sw" style="background:#4CC9F0"></span><span id="lA"></span></label>
  <label><input type="checkbox" id="tB" checked> <span class="sw" style="background:#FF5A2A"></span><span id="lB"></span></label>
  <label><input type="checkbox" id="tL"> <span class="sw" style="background:#F4D35E"></span>Líneas de separación</label>
  <p class="muted">Clic en el mapa: muestra el punto más cercano de cada logger.</p>
</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const D = __DATA__;
const COLORS = ['#4CC9F0', '#FF5A2A'];
const $ = id => document.getElementById(id);
['A','B'].forEach((k, i) => {
  const s = D.stats[i];
  $('h'+k).textContent = D.names[i]; $('l'+k).textContent = D.names[i];
  $('h'+k).style.color = COLORS[i];
  $('km'+k).textContent = s.km + ' km'; $('min'+k).textContent = s.minutes + ' min';
  $('v'+k).textContent = s.vmax + ' km/h'; $('p'+k).textContent = s.points;
  $('a'+k).textContent = s.acc + ' m';
});
$('s50').textContent = D.sep.p50 + ' m'; $('s90').textContent = D.sep.p90 + ' m';
$('smax').textContent = D.sep.max + ' m'; $('sn').textContent = D.sep.pairs;

const map = L.map('map', { maxZoom: 22 });
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
  maxZoom: 22, maxNativeZoom: 19, attribution: 'Esri World Imagery'
}).addTo(map);

const layers = D.tracks.map((T, i) => {
  const g = L.layerGroup([
    L.polyline(T.map(p => [p[0], p[1]]), { color: COLORS[i], weight: 3, opacity: .85 }),
    L.circleMarker([T[0][0], T[0][1]], { radius: 6, color: '#fff', weight: 2,
      fillColor: COLORS[i], fillOpacity: 1 }).bindPopup(D.names[i] + ' inicio'),
  ]);
  return g.addTo(map);
});
const linkLayer = L.layerGroup(D.links.map(l =>
  L.polyline([[l[0], l[1]], [l[2], l[3]]], { color: '#F4D35E', weight: 1, opacity: .8 })));

$('tA').onchange = e => e.target.checked ? layers[0].addTo(map) : map.removeLayer(layers[0]);
$('tB').onchange = e => e.target.checked ? layers[1].addTo(map) : map.removeLayer(layers[1]);
$('tL').onchange = e => e.target.checked ? linkLayer.addTo(map) : map.removeLayer(linkLayer);

map.fitBounds(L.latLngBounds(D.tracks.flat().map(p => [p[0], p[1]])).pad(0.08));

map.on('click', e => {
  const lines = D.tracks.map((T, i) => {
    let best = 0, bestD = Infinity;
    T.forEach((p, j) => {
      const d = map.distance(e.latlng, L.latLng(p[0], p[1]));
      if (d < bestD) { bestD = d; best = j; }
    });
    const p = T[best];
    return '<b style="color:' + COLORS[i] + '">' + D.names[i] + '</b> #' + (best + 1) +
      ' · ' + p[2] + ' km/h · sats ' + p[3] + ' · acc ' + p[4] + ' m';
  });
  L.popup().setLatLng(e.latlng).setContent(lines.join('<br>')).openOn(map);
});
</script>
</body>
</html>
"""
    DST.write_text(html.replace("__DATA__", json.dumps(data)), encoding="utf-8")
    print(json.dumps({"stats": data["stats"], "sep": sep}, indent=2))
    print("->", DST)


if __name__ == "__main__":
    main()
