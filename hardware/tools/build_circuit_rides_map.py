"""Map rides inside a circuit whose two edges were walked/ridden with loggers.

Usage:
  python build_circuit_rides_map.py --edges <edgeA.ndjson> <edgeB.ndjson>
      --rides <r1.ndjson> [r2 ...] [--out map.html]

A ride point counts as "en pista" when dA + dB <= w + TOL, with dA/dB the
distances to the nearest point of each edge and w the distance between those
two edge points (an ellipse test that follows the local track width).
Laps are counted as returns to the ride's own start point.
"""

import json
import math
import pathlib
import sys

from build_session_map import dedupe, haversine, load

TOL_M = 3.0
LAP_RADIUS_M = 10.0
LAP_MIN_S = 25.0


def arg_list(flag):
    if flag not in sys.argv:
        return []
    out = []
    for a in sys.argv[sys.argv.index(flag) + 1:]:
        if a.startswith("--"):
            break
        out.append(pathlib.Path(a))
    return out


EDGES = arg_list("--edges")
RIDES = arg_list("--rides")
OUT = arg_list("--out")
DST = OUT[0] if OUT else pathlib.Path(__file__).resolve().parents[1] / "captures" / "circuit_rides.html"


class Grid:
    """Nearest-point lookup in local metres (equirectangular around lat0)."""

    def __init__(self, pts, lat0, cell=5.0):
        self.k = math.cos(math.radians(lat0)) * 111320.0
        self.cell = cell
        self.xy = [(p["lng"] * self.k, p["lat"] * 110540.0) for p in pts]
        self.cells = {}
        for i, (x, y) in enumerate(self.xy):
            self.cells.setdefault((int(x // cell), int(y // cell)), []).append(i)

    def nearest(self, p):
        x, y = p["lng"] * self.k, p["lat"] * 110540.0
        cx, cy = int(x // self.cell), int(y // self.cell)
        best, bd = None, float("inf")
        for r in range(1, 12):
            for gx in range(cx - r, cx + r + 1):
                for gy in range(cy - r, cy + r + 1):
                    for i in self.cells.get((gx, gy), ()):
                        d = math.hypot(self.xy[i][0] - x, self.xy[i][1] - y)
                        if d < bd:
                            bd, best = d, i
            if best is not None and bd <= r * self.cell:
                break
        return best, bd


def laps(pts):
    start, out, last_t, away = pts[0], [], pts[0]["t_us"], False
    for p in pts[1:]:
        d = haversine(start, p)
        if d > LAP_RADIUS_M * 3:
            away = True
        if away and d < LAP_RADIUS_M and (p["t_us"] - last_t) / 1e6 > LAP_MIN_S:
            out.append(round((p["t_us"] - last_t) / 1e6, 1))
            last_t, away = p["t_us"], False
    return out


def main():
    if len(EDGES) != 2 or not RIDES:
        raise SystemExit(__doc__)
    edges = [dedupe(load(p)) for p in EDGES]
    lat0 = edges[0][0]["lat"]
    grids = [Grid(e, lat0) for e in edges]

    rides = []
    for path in RIDES:
        pts = dedupe(load(path))
        inside = []
        for p in pts:
            ia, da = grids[0].nearest(p)
            ib, db = grids[1].nearest(p)
            w = haversine(edges[0][ia], edges[1][ib])
            inside.append(1 if da + db <= w + TOL_M else 0)
        speeds = [p.get("speed_mps", 0) * 3.6 for p in pts]
        lap_s = laps(pts)
        rides.append({
            "name": path.parent.name[9:18] if path.name == "gnss.ndjson" else path.stem[9:18],
            "km": round(sum(haversine(a, b) for a, b in zip(pts, pts[1:])) / 1000, 3),
            "minutes": round((pts[-1]["t_us"] - pts[0]["t_us"]) / 6e7, 1),
            "vmax": round(max(speeds), 1),
            "vavg": round(sum(speeds) / len(speeds), 1),
            "inside": round(100 * sum(inside) / len(inside), 1),
            "laps": lap_s,
            "best": min(lap_s) if lap_s else None,
            "track": [[round(p["lat"], 7), round(p["lng"], 7), round(s, 1), f]
                      for p, s, f in zip(pts, speeds, inside)],
        })
        print(rides[-1]["name"], {k: v for k, v in rides[-1].items() if k != "track"})

    data = {
        "edges": [[[round(p["lat"], 7), round(p["lng"], 7)] for p in e] for e in edges],
        "rides": rides,
        "vmax": max(r["vmax"] for r in rides),
    }

    html = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>RiderLab — rodadas en el circuito</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<style>
  html, body { margin: 0; height: 100%; background: #101214; color: #e8e8e8;
    font: 13px/1.45 system-ui, sans-serif; }
  #map { position: absolute; inset: 0; }
  .panel { position: absolute; z-index: 500; top: 12px; left: 12px; width: 330px;
    background: rgba(16,18,20,.93); border: 1px solid #2c3136; border-radius: 10px;
    padding: 12px 14px; }
  .panel h1 { margin: 0 0 8px; font-size: 15px; }
  table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
  th { text-align: right; font-weight: 600; color: #8b939b; font-size: 11px; }
  th:first-child, td:first-child { text-align: left; }
  td { padding: 3px 0; text-align: right; }
  .sw { display: inline-block; width: 12px; height: 4px; border-radius: 2px; margin-right: 6px;
    vertical-align: middle; }
  .muted { color: #8b939b; font-size: 12px; margin-top: 8px; }
  .mode label { margin-right: 10px; cursor: pointer; }
  .laps { color: #8b939b; font-size: 11px; }
</style>
</head>
<body>
<div id="map"></div>
<div class="panel">
  <h1>Rodadas sobre el circuito mapeado</h1>
  <table id="tbl">
    <tr><th></th><th>km</th><th>min</th><th>máx</th><th>vueltas</th><th>mejor</th><th>en pista</th></tr>
  </table>
  <div class="mode" style="margin-top:8px">Color:
    <label><input type="radio" name="m" value="ride" checked> por rodada</label>
    <label><input type="radio" name="m" value="speed"> velocidad</label>
    <label><input type="radio" name="m" value="inside"> dentro/fuera</label>
  </div>
  <p class="muted">Bordes blancos = las 2 pasadas de mapeo. "En pista" = puntos entre los
  dos bordes (±3 m). Vueltas = regresos al punto de arranque de cada rodada.</p>
</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const D = __DATA__;
const COLORS = ['#4CC9F0', '#7CFC9A', '#FF5A2A', '#C77DFF', '#F4D35E'];
const map = L.map('map', { maxZoom: 22 });
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
  maxZoom: 22, maxNativeZoom: 19, attribution: 'Esri World Imagery'
}).addTo(map);

D.edges.forEach(e => L.polyline(e, { color: '#ffffff', weight: 2, opacity: .75, dashArray: '4 4' }).addTo(map));

function speedColor(v) {
  const t = Math.max(0, Math.min(1, v / Math.max(1, D.vmax)));
  const s = [[0,'#4CC9F0'],[0.33,'#7CFC9A'],[0.66,'#F4D35E'],[1,'#FF5A2A']];
  for (let i = 1; i < s.length; i++) if (t <= s[i][0]) return s[i][1];
  return s[s.length - 1][1];
}

const shown = D.rides.map(() => true);
const groups = D.rides.map(() => L.layerGroup().addTo(map));
let mode = 'ride';

function draw() {
  D.rides.forEach((r, i) => {
    const g = groups[i];
    g.clearLayers();
    if (!shown[i]) return;
    if (mode === 'ride') {
      g.addLayer(L.polyline(r.track.map(p => [p[0], p[1]]), { color: COLORS[i % 5], weight: 3, opacity: .9 }));
    } else {
      for (let j = 1; j < r.track.length; j++) {
        const p = r.track[j];
        const c = mode === 'speed' ? speedColor(p[2]) : (p[3] ? '#7CFC9A' : '#FF3B3B');
        g.addLayer(L.polyline([[r.track[j-1][0], r.track[j-1][1]], [p[0], p[1]]], { color: c, weight: 3, opacity: .9 }));
      }
    }
  });
}

const tbl = document.getElementById('tbl');
D.rides.forEach((r, i) => {
  const tr = document.createElement('tr');
  tr.innerHTML = '<td><label><input type="checkbox" checked> <span class="sw" style="background:' +
    COLORS[i % 5] + '"></span>' + (i + 1) + '</label></td><td>' + r.km + '</td><td>' + r.minutes +
    '</td><td>' + r.vmax + '</td><td>' + r.laps.length + '</td><td>' + (r.best ?? '–') +
    (r.best ? ' s' : '') + '</td><td>' + r.inside + ' %</td>';
  tr.querySelector('input').onchange = e => { shown[i] = e.target.checked; draw(); };
  tbl.appendChild(tr);
  if (r.laps.length) {
    const lr = document.createElement('tr');
    lr.innerHTML = '<td colspan="7" class="laps">vueltas: ' + r.laps.map(s => s + ' s').join(' · ') + '</td>';
    tbl.appendChild(lr);
  }
});
document.querySelectorAll('input[name=m]').forEach(el => el.onchange = e => { mode = e.target.value; draw(); });
draw();
map.fitBounds(L.latLngBounds(D.edges.flat()).pad(0.08));

map.on('click', e => {
  const lines = [];
  D.rides.forEach((r, i) => {
    if (!shown[i]) return;
    let best = 0, bd = Infinity;
    r.track.forEach((p, j) => { const d = map.distance(e.latlng, L.latLng(p[0], p[1])); if (d < bd) { bd = d; best = j; } });
    if (bd < 25) lines.push('<b style="color:' + COLORS[i % 5] + '">Rodada ' + (i + 1) + '</b> ' +
      r.track[best][2] + ' km/h · ' + (r.track[best][3] ? 'en pista' : 'fuera'));
  });
  if (lines.length) L.popup().setLatLng(e.latlng).setContent(lines.join('<br>')).openOn(map);
});
</script>
</body>
</html>
"""
    DST.write_text(html.replace("__DATA__", json.dumps(data)), encoding="utf-8")
    print("->", DST)


if __name__ == "__main__":
    main()
