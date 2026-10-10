"""Rider GPX: Sunday checkpoints + fuel + meta + road, no night transfer."""

import math
import pathlib
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parents[1] / "captures"
SRC = HERE / "ruta_off_1_recuperacion.gpx"
OUTS = [
    HERE / "ruta_off_1_recuperacion.gpx",
    HERE / "ruta_off_1_recuperacion_checkpoints.gpx",
    pathlib.Path(r"C:\Users\jvald\Downloads") / "ruta_off_1_recuperacion.gpx",
    pathlib.Path(r"C:\Users\jvald\Downloads") / "ruta_off_1_recuperacion_checkpoints.gpx",
]
KEEP = {"checkpoint", "fuel", "depot"}
NS = {"gpx": "http://www.topografix.com/GPX/1/1"}
ET.register_namespace("", "http://www.topografix.com/GPX/1/1")


def dist_m(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dphi = p2 - p1
    dl = math.radians(b[1] - a[1])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(min(1.0, h)))


def main():
    tree = ET.parse(SRC)
    root = tree.getroot()
    gpx_ns = "{http://www.topografix.com/GPX/1/1}"

    first_cp = None
    kept_wpt = []
    for wpt in list(root.findall("gpx:wpt", NS)):
        kind = (wpt.findtext("gpx:type", default="", namespaces=NS) or "").strip()
        if kind not in KEEP:
            root.remove(wpt)
            continue
        kept_wpt.append(wpt)
        if kind == "checkpoint" and first_cp is None:
            first_cp = (float(wpt.get("lat")), float(wpt.get("lon")))

    for trk in list(root.findall("gpx:trk", NS)):
        name = (trk.findtext("gpx:name", default="", namespaces=NS) or "").strip()
        if name != "domingo":
            root.remove(trk)
            continue
        if first_cp is None:
            continue
        seg = trk.find("gpx:trkseg", NS)
        if seg is None:
            continue
        pts = list(seg.findall("gpx:trkpt", NS))
        best_i, best_d = 0, 1e18
        for i, pt in enumerate(pts):
            d = dist_m(first_cp, (float(pt.get("lat")), float(pt.get("lon"))))
            if d < best_d:
                best_i, best_d = i, d
        for pt in pts[:best_i]:
            seg.remove(pt)

    meta = root.find("gpx:metadata", NS)
    if meta is not None:
        name = meta.find("gpx:name", NS)
        desc = meta.find("gpx:desc", NS)
        if name is not None:
            name.text = "rally off 1 - domingo checkpoints"
        if desc is not None:
            desc.text = "Ruta domingo: primer checkpoint a meta. Sin traslado de noche."

    # Pretty-ish write
    xml = ET.tostring(root, encoding="unicode")
    header = '<?xml version="1.0" encoding="UTF-8"?>\n'
    text = header + xml
    if not text.endswith("\n"):
        text += "\n"
    # Avoid unused var warning if register only
    _ = gpx_ns
    for dest in OUTS:
        dest.write_text(text, encoding="utf-8")
        print("->", dest)
    print(f"{len(kept_wpt)} waypoints | track desde primer CP")


if __name__ == "__main__":
    main()
