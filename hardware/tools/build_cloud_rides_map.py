"""Build a Leaflet map of every logger session downloaded from Azure.

Usage: python build_cloud_rides_map.py
Reads hardware/captures/cloud/unpaired/*/gnss.ndjson
Writes hardware/captures/cloud_rides.html
"""

from __future__ import annotations

import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "captures"
SRC = ROOT / "cloud" / "unpaired"
DST = ROOT / "cloud_rides.html"
UPLOAD_CAP = 23000

COLORS = [
    "#fb923c",
    "#4ade80",
    "#60a5fa",
    "#f472b6",
    "#facc15",
    "#22d3ee",
    "#a78bfa",
    "#f87171",
    "#34d399",
    "#38bdf8",
    "#e879f9",
    "#fbbf24",
    "#2dd4bf",
    "#c084fc",
    "#fb7185",
]


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dphi = p2 - p1
    dl = math.radians(b[1] - a[1])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(min(1.0, h)))


def hhmm(utc_ms):
    if utc_ms is None:
        return ""
    sec = int(utc_ms / 1000) % 86400
    return f"{sec // 3600:02d}:{sec % 3600 // 60:02d}"


def load_ride(folder: pathlib.Path, color: str):
    gnss_path = folder / "gnss.ndjson"
    man_path = folder / "manifest.json"
    manifest = json.loads(man_path.read_text(encoding="utf-8")) if man_path.exists() else {}
    raw = []
    for line in gnss_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("lat") and rec.get("lng"):
            raw.append(rec)
    pts = []
    for r in raw:
        if pts and pts[-1]["lat"] == r["lat"] and pts[-1]["lng"] == r["lng"]:
            continue
        pts.append(r)
    dist = 0.0
    hops = []
    for a, b in zip(pts, pts[1:]):
        d = haversine((a["lat"], a["lng"]), (b["lat"], b["lng"]))
        dist += d
        hops.append(d)
    speeds = [p.get("speed_mps", 0) * 3.6 for p in pts] or [0.0]
    t0 = pts[0]["t_us"] if pts else 0
    t1 = pts[-1]["t_us"] if pts else 0
    utc0 = pts[0].get("utc_ms") if pts else None
    utc1 = pts[-1].get("utc_ms") if pts else None
    size = gnss_path.stat().st_size
    track = [[round(p["lat"], 7), round(p["lng"], 7)] for p in pts]
    return {
        "id": folder.name,
        "short": folder.name[9:13],
        "version": manifest.get("version") or "",
        "gnss_count": (manifest.get("counts") or {}).get("gnss", len(raw)),
        "points": len(pts),
        "samples": len(raw),
        "km": round(dist / 1000, 3),
        "minutes": round(max(0, t1 - t0) / 1e6 / 60, 1),
        "vmax": round(max(speeds), 1),
        "vavg": round(sum(speeds) / len(speeds), 1),
        "sats": max((p.get("sats") or 0) for p in pts) if pts else 0,
        "start": hhmm(utc0),
        "end": hhmm(utc1),
        "truncated": size >= UPLOAD_CAP,
        "bytes": size,
        "color": color,
        "track": track,
    }


def main():
    folders = sorted([p for p in SRC.iterdir() if p.is_dir()], key=lambda p: p.name)
    rides = [load_ride(folder, COLORS[i % len(COLORS)]) for i, folder in enumerate(folders)]
    rides.sort(key=lambda r: (r["start"] or "99", r["id"]))
    for i, ride in enumerate(rides):
        ride["n"] = i + 1
        ride["color"] = COLORS[i % len(COLORS)]

    payload = json.dumps(rides, ensure_ascii=False, separators=(",", ":"))
    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RiderLab — 15 rides en la nube</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body{{margin:0;height:100%;font:14px/1.45 system-ui,Segoe UI,sans-serif;background:#0d1117;color:#e6edf3}}
  #wrap{{display:flex;height:100%}}
  #map{{flex:1}}
  #side{{width:360px;overflow:auto;padding:14px 16px;background:#11161d;border-left:1px solid #222b36}}
  h1{{font-size:16px;margin:0 0 4px}}
  .sub{{color:#8b98a5;font-size:12px;margin-bottom:12px}}
  .kpi{{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px}}
  .card{{background:#161c24;border:1px solid #222b36;border-radius:8px;padding:8px 10px}}
  .card b{{display:block;font-size:18px;color:#4ade80}}
  .card span{{font-size:11px;color:#8b98a5}}
  ol{{list-style:none;margin:0;padding:0}}
  li{{display:flex;gap:9px;padding:8px 0;border-bottom:1px solid #1c232c;cursor:pointer}}
  li.off{{opacity:.35}}
  .sw{{flex:0 0 12px;width:12px;height:12px;border-radius:50%;margin-top:5px}}
  .nm{{font-weight:600}}
  .meta{{color:#8b98a5;font-size:11px}}
  .tag{{font-size:10px;padding:1px 5px;border-radius:4px;background:#3f1d1d;color:#fca5a5;margin-left:4px}}
</style>
</head>
<body>
<div id="wrap"><div id="map"></div><div id="side"></div></div>
<script>
const RIDES = {payload};
const map = L.map('map', {{zoomControl:true, maxZoom:22, minZoom:5}});
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{{z}}/{{y}}/{{x}}',
  {{maxZoom:22, maxNativeZoom:19, attribution:'Esri World Imagery'}}).addTo(map);
const layers = {{}};
const bounds = L.latLngBounds([]);
RIDES.forEach(r => {{
  if (!r.track.length) return;
  const line = L.polyline(r.track, {{color:r.color, weight:4, opacity:.9}}).addTo(map);
  const start = L.circleMarker(r.track[0], {{radius:6, color:'#fff', weight:1, fillColor:r.color, fillOpacity:1}})
    .bindPopup('#'+r.n+' inicio '+r.start);
  const end = L.circleMarker(r.track[r.track.length-1], {{radius:6, color:'#fff', weight:1, fillColor:'#111', fillOpacity:1}})
    .bindPopup('#'+r.n+' fin '+r.end);
  start.addTo(map); end.addTo(map);
  layers[r.id] = {{line, start, end, on:true}};
  r.track.forEach(p => bounds.extend(p));
}});
if (bounds.isValid()) map.fitBounds(bounds.pad(0.04), {{maxZoom:21}});

const km = RIDES.reduce((s,r)=>s+r.km,0);
const pts = RIDES.reduce((s,r)=>s+r.points,0);
const trunc = RIDES.filter(r=>r.truncated).length;
const side = document.getElementById('side');
side.innerHTML = `
  <h1>15 rides en Azure</h1>
  <div class="sub">device unpaired · logger-sessions · 3 oct 2026<br>
    click una ride para encuadrarla · click de nuevo para ocultarla</div>
  <div class="kpi">
    <div class="card"><b>${{RIDES.length}}</b><span>sesiones en la nube</span></div>
    <div class="card"><b>${{km.toFixed(2)}} km</b><span>suma de trazas</span></div>
    <div class="card"><b>${{pts}}</b><span>puntos GPS unicos</span></div>
    <div class="card"><b>${{trunc}}</b><span>recortadas al tope 24 kB</span></div>
  </div>
  <ol>${{RIDES.map(r => `
    <li data-id="${{r.id}}">
      <div class="sw" style="background:${{r.color}}"></div>
      <div>
        <div class="nm">#${{r.n}} ${{r.start || '--:--'}}–${{r.end || '--:--'}} UTC
          ${{r.truncated ? '<span class="tag">recorte 24k</span>' : ''}}</div>
        <div class="meta">${{r.km}} km · ${{r.minutes}} min · max ${{r.vmax}} km/h ·
          ${{r.points}} pts · ${{r.version}} · ${{r.short}}</div>
      </div>
    </li>`).join('')}}</ol>`;

document.querySelectorAll('#side li').forEach(li => {{
  li.onclick = () => {{
    const r = RIDES.find(x => x.id === li.dataset.id);
    const Lr = layers[r.id];
    if (!Lr) return;
    if (Lr.on && li.classList.contains('active')) {{
      Lr.line.remove(); Lr.start.remove(); Lr.end.remove();
      Lr.on = false; li.classList.add('off'); li.classList.remove('active');
      return;
    }}
    if (!Lr.on) {{
      Lr.line.addTo(map); Lr.start.addTo(map); Lr.end.addTo(map);
      Lr.on = true; li.classList.remove('off');
    }}
    document.querySelectorAll('#side li').forEach(x => x.classList.remove('active'));
    li.classList.add('active');
    if (r.track.length) map.fitBounds(L.latLngBounds(r.track).pad(0.06), {{maxZoom:21}});
  }};
}});
</script>
</body>
</html>
"""
    DST.write_text(html, encoding="utf-8")
    print(f"{len(rides)} rides -> {DST}")
    for r in rides:
        flag = " TRUNC" if r["truncated"] else ""
        print(
            f"  #{r['n']:02d} {r['start']}-{r['end']}  {r['km']:6.3f} km  "
            f"{r['minutes']:5.1f} min  {r['points']:4} pts  {r['version']}{flag}"
        )


if __name__ == "__main__":
    main()
