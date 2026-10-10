"""Export only recovery checkpoints (no tracks, hotel, fuel, pickup).

Reads ruta_off_1_recuperacion.gpx waypoints with type=checkpoint.
Writes .gpx + .html and copies the GPX to Downloads.
"""

import pathlib
import re
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parents[1] / "captures"
SRC = HERE / "ruta_off_1_recuperacion.gpx"
GPX_OUT = HERE / "ruta_off_1_recuperacion_checkpoints.gpx"
HTML_OUT = HERE / "ruta_off_1_recuperacion_checkpoints.html"
DOWNLOADS = pathlib.Path(r"C:\Users\jvald\Downloads") / "ruta_off_1_recuperacion_checkpoints.gpx"
NS = {"gpx": "http://www.topografix.com/GPX/1/1"}


def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    root = ET.parse(SRC).getroot()
    cps = []
    for wpt in root.findall("gpx:wpt", NS):
        kind = (wpt.findtext("gpx:type", default="", namespaces=NS) or "").strip()
        if kind != "checkpoint":
            continue
        name = re.sub(
            r"^\d+\s+",
            "",
            (wpt.findtext("gpx:name", default="", namespaces=NS) or "").strip(),
        )
        desc = (wpt.findtext("gpx:desc", default="", namespaces=NS) or "").strip()
        arrive = ""
        points = 0
        for part in desc.split("|"):
            part = part.strip()
            if part.startswith("dia ") and " " in part:
                bits = part.split()
                if len(bits) >= 3:
                    arrive = bits[2]
            if part.endswith("pts"):
                try:
                    points = int(part.split()[0])
                except ValueError:
                    points = 0
        cps.append(
            {
                "lat": float(wpt.get("lat")),
                "lng": float(wpt.get("lon")),
                "name": name,
                "desc": desc,
                "arrive": arrive,
                "points": points,
            }
        )
    if not cps:
        raise SystemExit("no checkpoint waypoints in " + str(SRC))

    wpts = []
    for i, c in enumerate(cps, 1):
        wpts.append(
            f'  <wpt lat="{c["lat"]}" lon="{c["lng"]}">\n'
            f'    <name>{i} {esc(c["name"])}</name>\n'
            f'    <desc>{esc(c["desc"])}</desc>\n'
            f"    <type>checkpoint</type>\n"
            f"  </wpt>"
        )
    gpx = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<gpx version="1.1" creator="RiderLab optimize_recovery" '
        'xmlns="http://www.topografix.com/GPX/1/1">\n'
        "  <metadata><name>rally off 1 - checkpoints recuperacion</name>"
        f"<desc>{len(cps)} checkpoints domingo, sin traza</desc></metadata>\n"
        + "\n".join(wpts)
        + "\n</gpx>\n"
    )
    GPX_OUT.write_text(gpx, encoding="utf-8")
    DOWNLOADS.write_text(gpx, encoding="utf-8")

    rows = []
    for i, c in enumerate(cps, 1):
        rows.append(
            "{"
            f'"n":{i},"name":{c["name"]!r},"arrive":{c["arrive"]!r},'
            f'"points":{c["points"]},"lat":{c["lat"]},"lng":{c["lng"]},'
            f'"desc":{c["desc"]!r}'
            "}"
        )
    payload = "[" + ",".join(rows) + "]"
    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Recuperacion — solo checkpoints</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  html,body{{margin:0;height:100%;font:14px/1.45 system-ui,Segoe UI,sans-serif;background:#0d1117;color:#e6edf3}}
  #wrap{{display:flex;height:100%}}
  #map{{flex:1}}
  #side{{width:340px;overflow:auto;padding:14px 16px;background:#11161d;border-left:1px solid #222b36}}
  h1{{font-size:16px;margin:0 0 4px}}
  .sub{{color:#8b98a5;font-size:12px;margin-bottom:12px}}
  ol{{list-style:none;margin:0;padding:0}}
  li{{display:flex;gap:9px;padding:8px 0;border-bottom:1px solid #1c232c;cursor:pointer}}
  .num{{flex:0 0 26px;height:26px;border-radius:50%;background:#2563eb;color:#fff;
        font:600 11px/26px system-ui;text-align:center}}
  .nm{{font-weight:600}}
  .meta{{color:#8b98a5;font-size:11px}}
</style>
</head>
<body>
<div id="wrap"><div id="map"></div><div id="side"></div></div>
<script>
const C = {payload};
const map = L.map('map', {{zoomControl:true, maxZoom:22}});
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{{z}}/{{y}}/{{x}}',
  {{maxZoom:22, maxNativeZoom:19, attribution:'Esri World Imagery'}}).addTo(map);
const bounds = L.latLngBounds([]);
C.forEach(r => {{
  const icon = L.divIcon({{
    className:'',
    html:`<div style="width:26px;height:26px;border-radius:50%;background:#2563eb;border:2px solid #fff;
      color:#fff;font:600 11px/22px system-ui;text-align:center">${{r.n}}</div>`,
    iconSize:[26,26], iconAnchor:[13,13]
  }});
  L.marker([r.lat, r.lng], {{icon}}).addTo(map).bindPopup(
    `<b>${{r.arrive}} · ${{r.name}}</b><br>${{r.points}} pts<br><small>${{r.desc}}</small>`);
  bounds.extend([r.lat, r.lng]);
}});
map.fitBounds(bounds.pad(0.08));
document.getElementById('side').innerHTML = `
  <h1>Checkpoints domingo</h1>
  <div class="sub">${{C.length}} pines · sin traza de carretera<br>GPX: ruta_off_1_recuperacion_checkpoints.gpx</div>
  <ol>${{C.map(r => `
    <li data-lat="${{r.lat}}" data-lng="${{r.lng}}">
      <div class="num">${{r.n}}</div>
      <div><div class="nm">${{r.arrive}} ${{r.name}}</div>
      <div class="meta">${{r.points}} pts</div></div>
    </li>`).join('')}}</ol>`;
document.querySelectorAll('#side li').forEach(li => {{
  li.onclick = () => map.setView([+li.dataset.lat, +li.dataset.lng], 15);
}});
</script>
</body>
</html>
"""
    HTML_OUT.write_text(html, encoding="utf-8")
    print(f"{len(cps)} checkpoints")
    print("->", GPX_OUT)
    print("->", HTML_OUT)
    print("->", DOWNLOADS)
    for i, c in enumerate(cps, 1):
        print(f"  {i:2} {c['arrive']} {c['name']}  {c['points']} pts")


if __name__ == "__main__":
    main()
