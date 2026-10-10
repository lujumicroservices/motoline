"""Render the recovery rally plan as a standalone Leaflet map + GPX.

Reads the JSON produced by optimize_recovery.py.

Usage: python build_recovery_map.py
"""

import csv
import json
import math
import pathlib

HERE = pathlib.Path(__file__).resolve().parents[1] / "captures"
SRC = HERE / "ruta_off_1_recuperacion.json"
DST = HERE / "ruta_off_1_recuperacion.html"
EXCEL = HERE / "Checkpoints_Rally_2026.csv"

data = json.loads(SRC.read_text(encoding="utf-8"))
stats = data["stats"]
plan = data["plan"]
days = data["days"]
shapes = data.get("shapes") or {}


def _near(a, b, meters=120):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dphi = p2 - p1
    dl = math.radians(b[1] - a[1])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(min(1.0, h))) <= meters


def all_official():
    marked = [
        (e["lat"], e["lng"], (e.get("name") or "").strip().lower())
        for e in plan
        if e.get("kind") == "checkpoint"
    ]
    out = []
    if not EXCEL.exists():
        return out
    with EXCEL.open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            coord = (row.get("Coordenadas") or "").replace('"', "").strip()
            if "," not in coord:
                continue
            lat_s, lng_s = coord.split(",", 1)
            try:
                lat, lng = float(lat_s), float(lng_s)
            except ValueError:
                continue
            name = (row.get("CHECKPOINT") or "").strip()
            pts_s = (row.get("puntos") or "0").replace("+", "").replace("pts", "").strip()
            try:
                points = int(float(pts_s))
            except ValueError:
                points = 0
            visited = any(
                _near((lat, lng), (m[0], m[1])) or name.lower() == m[2]
                for m in marked
            )
            out.append(
                {
                    "name": name,
                    "desc": row.get("EVIDENCIA") or "",
                    "lat": lat,
                    "lng": lng,
                    "orig": int(row.get("no") or 0),
                    "points": points,
                    "terrain": "",
                    "visited": visited,
                }
            )
    return out


official = all_official()
skipped = [p for p in official if not p["visited"]]
cp_n = 0
rows = []
for e in plan:
    if e["kind"] == "checkpoint":
        cp_n += 1
        num = str(cp_n)
    elif e["kind"] == "fuel":
        num = "G"
    elif e["kind"] == "hotel":
        num = "H"
    elif e["kind"] == "pickup":
        num = "P"
    elif e["kind"] == "start":
        num = "6"
    else:
        num = "M"
    rows.append(
        {
            "kind": e["kind"],
            "num": num,
            "name": e["name"],
            "desc": e.get("desc") or "",
            "lat": e["lat"],
            "lng": e["lng"],
            "terrain": e.get("terrain") or "",
            "points": e.get("points") or 0,
            "orig": e.get("orig") or 0,
            "leg_min": e.get("leg_min") or 0,
            "leg_km": e.get("leg_km") or 0,
            "day": e["day"],
            "arrive": e.get("arrive_hhmm") or "",
            "dwell": e.get("dwell_min") or 0,
            "meal": bool(e.get("meal")),
        }
    )

payload = json.dumps(
    {
        "stats": stats,
        "days": days,
        "rows": rows,
        "skipped": skipped,
        "official": official,
        "excluded": stats.get("excluded_saturday") or [],
        "shape1": shapes.get("1") or [],
        "shape2": shapes.get("2") or [],
    },
    ensure_ascii=False,
    separators=(",", ":"),
)

html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rally off 1 &mdash; recuperacion</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body{{margin:0;height:100%;font:14px/1.45 system-ui,Segoe UI,sans-serif;background:#0d1117;color:#e6edf3}}
  #wrap{{display:flex;height:100%}}
  #map{{flex:1}}
  #side{{width:380px;overflow:auto;padding:14px 16px;background:#11161d;border-left:1px solid #222b36}}
  h1{{font-size:16px;margin:0 0 4px}}
  h2{{font-size:13px;margin:16px 0 6px;color:#93c5fd;text-transform:uppercase;letter-spacing:.04em}}
  .sub{{color:#8b98a5;font-size:12px;margin-bottom:12px}}
  .kpi{{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:10px}}
  .card{{background:#161c24;border:1px solid #222b36;border-radius:8px;padding:8px 10px}}
  .card b{{display:block;font-size:18px;color:#4ade80}}
  .card.sun b{{color:#fb923c}}
  .card.skip b{{color:#f87171}}
  .card span{{font-size:11px;color:#8b98a5}}
  ol{{list-style:none;margin:0;padding:0}}
  li{{display:flex;gap:9px;padding:7px 0;border-bottom:1px solid #1c232c}}
  .num{{flex:0 0 26px;height:26px;border-radius:50%;color:#fff;font-weight:600;
        display:flex;align-items:center;justify-content:center;font-size:11px}}
  .num.cp{{background:#2563eb}} .num.dirt{{background:#b45309}}
  .num.fuel{{background:#eab308;color:#111}} .num.hotel{{background:#a855f7}}
  .num.depot{{background:#22c55e}} .num.skip{{background:#6b7280}}
  .num.pickup{{background:#fb923c}} .num.start{{background:#a855f7}}
  .nm{{font-weight:600}}
  .meta{{color:#8b98a5;font-size:11px}}
  .tag{{font-size:10px;padding:1px 5px;border-radius:4px;background:#1f2937;color:#9ca3af;margin-left:4px}}
  .legend{{background:#11161d;color:#e6edf3;padding:8px 10px;border-radius:8px;font-size:12px;line-height:1.7}}
  .sw{{display:inline-block;width:18px;height:3px;vertical-align:middle;margin-right:6px}}
  @media(max-width:820px){{#wrap{{flex-direction:column}}#side{{width:auto;max-height:48%}}}}
</style>
</head>
<body>
<div id="wrap"><div id="map"></div><div id="side"></div></div>
<script>
const D = {payload};
const S = D.stats;

const map = L.map('map', {{zoomControl:true}});
const imagery = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{{z}}/{{y}}/{{x}}',
  {{maxZoom:19, attribution:'Esri World Imagery'}}).addTo(map);
const osm = L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png',
  {{maxZoom:19, attribution:'OpenStreetMap'}});

const night = L.polyline(D.shape1, {{color:'#fb923c', weight:4, opacity:.92}}).addTo(map);
const sun = L.polyline(D.shape2, {{color:'#4ade80', weight:4, opacity:.92}}).addTo(map);

function pin(color, label, dark) {{
  return L.divIcon({{
    className:'',
    html:`<div style="width:26px;height:26px;border-radius:50%;background:${{color}};
      border:2px solid #fff;color:${{dark?'#111':'#fff'}};font:600 11px/22px system-ui;text-align:center;
      box-shadow:0 1px 4px rgba(0,0,0,.6)">${{label}}</div>`,
    iconSize:[26,26], iconAnchor:[13,13]
  }});
}}

const marks = L.layerGroup().addTo(map);
D.rows.forEach(r => {{
  let color = '#22c55e', dark = false;
  if (r.kind === 'checkpoint') color = r.terrain === 'dirt' ? '#b45309' : '#2563eb';
  if (r.kind === 'fuel') {{ color = '#eab308'; dark = true; }}
  if (r.kind === 'hotel' || r.kind === 'start') color = '#a855f7';
  if (r.kind === 'pickup') color = '#fb923c';
  const m = L.marker([r.lat, r.lng], {{icon: pin(color, r.num, dark)}}).addTo(marks);
  m.bindPopup(
    `<b>${{r.arrive}} &middot; ${{r.name}}</b><br>${{r.desc||''}}<br>
     <small>dia ${{r.day}} &middot; ${{r.kind}} &middot; ${{r.points}} pts
     ${{r.orig ? ' &middot; orig '+r.orig : ''}}<br>
     tramo: ${{r.leg_min}} min / ${{r.leg_km}} km
     ${{r.dwell ? ' &middot; paro '+r.dwell+' min' : ''}}
     ${{r.meal ? ' &middot; refrigerio' : ''}}</small>`);
}});

const skipped = L.layerGroup();
const oficiales = (D.official && D.official.length) ? D.official : D.skipped;
oficiales.forEach(r => {{
  const miss = r.visited === false;
  L.circleMarker([r.lat, r.lng], {{
    radius: miss ? 6 : 4,
    color: '#fff',
    weight: 1,
    fillColor: miss ? '#ff2bd6' : '#22d3ee',
    fillOpacity: miss ? 0.95 : 0.7
  }}).addTo(skipped).bindPopup(
    `<b>${{miss ? 'Excel — no en la ruta' : 'Excel — si se marca'}}: ${{r.name}}</b><br>${{r.desc||''}}<br>
     <small>#${{r.orig}} &middot; ${{r.points}} pts</small>`);
}});
skipped.addTo(map);

const all = D.shape1.concat(D.shape2);
if (all.length) map.fitBounds(L.latLngBounds(all).pad(0.06));
L.control.layers({{'Satelital':imagery,'Mapa':osm}},
  {{'Noche':night,'Domingo':sun,'Paradas':marks,'Todos los CP (Excel)':skipped}},
  {{collapsed:false}}).addTo(map);

const legend = L.control({{position:'bottomleft'}});
legend.onAdd = () => {{
  const d = L.DomUtil.create('div','legend');
  d.innerHTML = `<span class="sw" style="background:#fb923c"></span>noche ${{D.days[0].km}} km<br>
   <span class="sw" style="background:#4ade80"></span>domingo ${{D.days[1].km}} km<br>
   hotel ${{S.hotel}} ${{S.hotel_arrive}} &middot; meta ${{S.finish}}<br>
   salir Zapopan a mas tardar ${{S.latest_depart}}`;
  return d;
}};
legend.addTo(map);

const cls = k => k === 'checkpoint' ? 'cp' : k;
const side = document.getElementById('side');
const byDay = {{1:[], 2:[]}};
D.rows.forEach(r => byDay[r.day].push(r));
const dayBlock = (label, rows) => `
  <h2>${{label}}</h2>
  <ol>${{rows.map(r => `
    <li data-lat="${{r.lat}}" data-lng="${{r.lng}}">
      <div class="num ${{cls(r.kind)}}${{r.kind==='checkpoint' && r.terrain==='dirt' ? ' dirt' : ''}}">${{r.num}}</div>
      <div><div class="nm">${{r.arrive}} ${{r.name}}
        ${{r.meal ? '<span class="tag">refrigerio</span>' : ''}}
        ${{r.orig ? '<span class="tag"># '+r.orig+'</span>' : ''}}</div>
      <div class="meta">${{r.leg_min}} min / ${{r.leg_km}} km
        ${{r.points ? ' &middot; '+r.points+' pts' : ''}}
        ${{r.dwell ? ' &middot; paro '+r.dwell+' min' : ''}}</div></div></li>`).join('')}}</ol>`;

side.innerHTML = `
  <h1>Rally off 1 &mdash; ruta de recuperacion</h1>
  <div class="sub">Noche: Periferico y Santa Margarita → hotel (sin puntos)<br>
    Domingo 06:00 → meta ${{S.finish}} (limite 11:30) &middot; holgura ${{S.slack_min}} min<br>
    Salir hoy a mas tardar <b style="color:#fb923c">${{S.latest_depart}}</b>
    &middot; ${{S.cp_min}} min por marca</div>
  <div class="kpi">
    <div class="card"><b>${{S.points}}</b><span>puntos (${{S.points_pct}}% de ${{S.points_available}})</span></div>
    <div class="card"><b>${{S.checkpoints_visited}}/${{S.checkpoints_total}}</b><span>checkpoints domingo</span></div>
    <div class="card sun"><b>${{D.days[0].km}} km</b><span>noche ${{D.days[0].start}}-${{D.days[0].end}} &middot; 0 pts</span></div>
    <div class="card"><b>${{D.days[1].km}} km</b><span>domingo ${{D.days[1].start}}-${{D.days[1].end}} &middot; ${{D.days[1].points}} pts</span></div>
    <div class="card"><b>${{S.loop_km}} km</b><span>${{S.ride_h}} h rodando &middot; ${{S.avg_kmh}} km/h</span></div>
    <div class="card skip"><b>${{S.excluded_saturday.length}}</b><span>CP de sabado ya marcados (no repetir)</span></div>
  </div>
  ${{dayBlock('Noche — traslado sin puntos', byDay[1])}}
  ${{dayBlock('Domingo 06:00 / meta 11:30', byDay[2])}}
  <h2>Ya marcados hasta Zacoalco — no repetir</h2>
  <ol>${{(D.excluded||[]).map(name => `
    <li>
      <div class="num skip">×</div>
      <div><div class="nm">${{name}}</div></div></li>`).join('')}}</ol>`;

document.querySelectorAll('#side li').forEach(li => {{
  if (!li.dataset.lat) return;
  li.style.cursor = 'pointer';
  li.onclick = () => map.setView([+li.dataset.lat, +li.dataset.lng], 14);
}});
</script>
</body>
</html>
"""

DST.write_text(html, encoding="utf-8")
print("->", DST)


def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


wpts = []
for r in rows:
    if r["kind"] not in ("checkpoint", "fuel", "depot"):
        continue
    wpts.append(
        f'  <wpt lat="{r["lat"]}" lon="{r["lng"]}">\n'
        f'    <name>{r["num"]} {esc(r["name"])}</name>\n'
        f'    <desc>dia {r["day"]} {r["arrive"]} | {r["kind"]} | {r["points"]} pts | '
        f'{r["leg_km"]} km</desc>\n'
        f"    <type>{r['kind']}</type>\n  </wpt>"
    )
trk = []
for day, pts in (("domingo", shapes.get("2") or []),):
    if not pts:
        continue
    body = "\n".join(f'      <trkpt lat="{a}" lon="{b}"/>' for a, b in pts)
    trk.append(f'  <trk><name>{day}</name><trkseg>\n{body}\n    </trkseg></trk>')

gpx = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<gpx version="1.1" creator="RiderLab optimize_recovery" '
    'xmlns="http://www.topografix.com/GPX/1/1">\n'
    "  <metadata><name>rally off 1 - recuperacion</name>"
    f'<desc>{stats["points"]} pts / {stats["loop_km"]} km / meta {stats["finish"]} / '
    f'salir {stats["latest_depart"]}</desc></metadata>\n'
    + "\n".join(wpts)
    + "\n"
    + "\n".join(trk)
    + "\n</gpx>\n"
)
gpx_path = HERE / "ruta_off_1_recuperacion.gpx"
gpx_path.write_text(gpx, encoding="utf-8")
downloads = pathlib.Path(r"C:\Users\jvald\Downloads") / "ruta_off_1_recuperacion.gpx"
downloads.write_text(gpx, encoding="utf-8")
print("->", gpx_path)
print("->", downloads)
print(f"{len(rows)} paradas | skip excel {len(skipped)}")
