#!/usr/bin/env python3
"""Download and analyze RiderLab rides for a calendar day.

Run from anywhere:

    python supabase/scripts/analyze_day_rides.py
    python supabase/scripts/analyze_day_rides.py --date 2026-09-13
    python supabase/scripts/analyze_day_rides.py --date today --rider "RT DobleU"

Writes a local report under tmp/ride-analysis/<date>/ so you can inspect
tracks without asking the agent to query the database again.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

REPO = Path(__file__).resolve().parents[2]
TZ_DEFAULT = "America/Mexico_City"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
COPY_PREFIX = "copy-from-"
EARTH_M = 6371000.0
TELEPORT_MPS = 70.0  # ~252 km/h; long highway hops are gaps, not teleports
GAP_S = 25.0
PAUSE_S = 30.0
PAUSE_M = 25.0
STOP_MPS = 1.2
LONG_PAUSE_S = 60.0
MAP_MAX_POINTS = 1800


def sql_lit(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def parse_dt(value: Any) -> datetime | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        text = str(value).replace(" ", "T")
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def local_fmt(dt: datetime | None, tz: ZoneInfo, with_date: bool = True) -> str:
    if dt is None:
        return "—"
    local = dt.astimezone(tz)
    return local.strftime("%Y-%m-%d %H:%M") if with_date else local.strftime("%H:%M")


def num(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    rlat1, rlon1, rlat2, rlon2 = map(math.radians, (lat1, lon1, lat2, lon2))
    dlat = rlat2 - rlat1
    dlon = rlon2 - rlon1
    a = math.sin(dlat / 2) ** 2 + math.cos(rlat1) * math.cos(rlat2) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_M * math.asin(min(1.0, math.sqrt(a)))


def pct(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    idx = (len(ordered) - 1) * p
    lo = math.floor(idx)
    hi = math.ceil(idx)
    if lo == hi:
        return ordered[lo]
    frac = idx - lo
    return ordered[lo] * (1 - frac) + ordered[hi] * frac


def fmt_km(meters: float | None) -> str:
    if meters is None:
        return "—"
    return f"{meters / 1000:.2f} km"


def fmt_kmh(mps: float | None) -> str:
    if mps is None:
        return "—"
    return f"{mps * 3.6:.1f} km/h"


def fmt_min(seconds: float | None) -> str:
    if seconds is None:
        return "—"
    total = int(round(seconds))
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}h {m:02d}m"
    if m:
        return f"{m}m {s:02d}s"
    return f"{s}s"


def npx_bin() -> str:
    return "npx.cmd" if os.name == "nt" else "npx"


def parse_query_payload(raw: str) -> list[dict[str, Any]]:
    text = raw.strip()
    if not text:
        return []
    start_obj = text.find("{")
    start_arr = text.find("[")
    starts = [i for i in (start_obj, start_arr) if i >= 0]
    if not starts:
        raise RuntimeError(f"supabase db query returned no JSON:\n{text[:800]}")
    start = min(starts)
    blob = text[start:]
    end_obj = blob.rfind("}")
    end_arr = blob.rfind("]")
    end = max(end_obj, end_arr)
    if end < 0:
        raise RuntimeError(f"supabase db query JSON was truncated:\n{text[:800]}")
    payload = json.loads(blob[: end + 1])
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        if payload.get("error"):
            raise RuntimeError(str(payload.get("error")))
        for key in ("rows", "data", "result", "results"):
            rows = payload.get(key)
            if isinstance(rows, list):
                return rows
        if any(k in payload for k in ("id", "display_name", "latitude", "ride_id")):
            return [payload]
    raise RuntimeError(f"unexpected db query JSON shape: {type(payload).__name__}")


def db_query(sql: str) -> list[dict[str, Any]]:
    with tempfile.TemporaryDirectory(prefix="riderlab-day-") as tmp:
        sql_path = Path(tmp) / "query.sql"
        sql_path.write_text(sql, encoding="utf-8")
        cmd = [
            npx_bin(),
            "--yes",
            "supabase",
            "db",
            "query",
            "--linked",
            "--workdir",
            str(REPO),
            "--output-format",
            "json",
            "-f",
            str(sql_path),
        ]
        proc = subprocess.run(
            cmd,
            cwd=str(REPO),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "").strip()
            raise RuntimeError(f"supabase db query failed ({proc.returncode}):\n{err[:2000]}")
        return parse_query_payload(proc.stdout)


def downsample(points: list[dict[str, Any]], max_points: int = MAP_MAX_POINTS) -> list[dict[str, Any]]:
    if len(points) <= max_points:
        return points
    step = max(1, math.ceil(len(points) / max_points))
    out = points[::step]
    if out[-1] is not points[-1]:
        out.append(points[-1])
    return out


@dataclass
class RideAnalysis:
    ride: dict[str, Any]
    points: list[dict[str, Any]]
    tz: ZoneInfo
    flags: list[str] = field(default_factory=list)
    gps_m: float = 0.0
    moving_m: float = 0.0
    duration_s: float | None = None
    moving_s: float = 0.0
    paused_s: float = 0.0
    hops: int = 0
    teleports: int = 0
    gaps: int = 0
    pauses: int = 0
    median_dt_s: float | None = None
    median_acc_m: float | None = None
    max_acc_m: float | None = None
    hop_max_kmh: float | None = None
    hop_p95_kmh: float | None = None
    lean_n: int = 0
    lean_ok: int = 0
    lean_p10: float | None = None
    lean_p50: float | None = None
    lean_p90: float | None = None
    lean_left: float | None = None
    lean_right: float | None = None
    pct_clamp70: float | None = None
    start_lat: float | None = None
    start_lng: float | None = None
    end_lat: float | None = None
    end_lng: float | None = None
    events: list[str] = field(default_factory=list)

    def analyze(self) -> None:
        ride = self.ride
        local_id = str(ride.get("local_id") or "")
        stored_m = num(ride.get("distance_meters")) or 0.0
        stored_n = int(num(ride.get("point_count")) or 0)
        started = parse_dt(ride.get("started_at"))
        ended = parse_dt(ride.get("ended_at"))
        if started and ended:
            self.duration_s = max(0.0, (ended - started).total_seconds())
        if local_id.startswith(COPY_PREFIX):
            self.flags.append("copia")
        if ended is None:
            self.flags.append("sin_fin")
        if not self.points:
            self.flags.append("sin_puntos")
            if stored_n:
                self.flags.append("puntos_no_sincronizados")
            return

        self.start_lat = num(self.points[0].get("latitude"))
        self.start_lng = num(self.points[0].get("longitude"))
        self.end_lat = num(self.points[-1].get("latitude"))
        self.end_lng = num(self.points[-1].get("longitude"))
        if self.duration_s is None:
            first = parse_dt(self.points[0].get("recorded_at"))
            last = parse_dt(self.points[-1].get("recorded_at"))
            if first and last:
                self.duration_s = max(0.0, (last - first).total_seconds())

        dt_list: list[float] = []
        acc_list: list[float] = []
        hop_kmh: list[float] = []
        leans: list[float] = []
        prev = None
        for pt in self.points:
            acc = num(pt.get("accuracy_meters"))
            if acc is not None:
                acc_list.append(acc)
            lean = num(pt.get("lean_degrees"))
            self.lean_n += 1
            if lean is not None:
                self.lean_ok += 1
                leans.append(lean)
            if prev is None:
                prev = pt
                continue
            lat1, lon1 = num(prev.get("latitude")), num(prev.get("longitude"))
            lat2, lon2 = num(pt.get("latitude")), num(pt.get("longitude"))
            t1, t2 = parse_dt(prev.get("recorded_at")), parse_dt(pt.get("recorded_at"))
            prev = pt
            if None in (lat1, lon1, lat2, lon2, t1, t2):
                continue
            hop = haversine_m(lat1, lon1, lat2, lon2)
            dt = (t2 - t1).total_seconds()
            self.hops += 1
            if dt < 0:
                self.flags.append("tiempo_regresivo")
                continue
            if dt > 0:
                dt_list.append(dt)
            inst_mps = hop / dt if dt > 0 else float("inf")
            if inst_mps >= TELEPORT_MPS:
                self.teleports += 1
                self.events.append(
                    f"teleport {local_fmt(t1, self.tz, with_date=False)} "
                    f"{hop:.0f} m en {dt:.1f}s ({inst_mps * 3.6:.0f} km/h)"
                )
                continue
            self.gps_m += hop
            if dt >= GAP_S:
                self.gaps += 1
                self.events.append(
                    f"hueco GPS {local_fmt(t1, self.tz, with_date=False)} a "
                    f"{local_fmt(t2, self.tz, with_date=False)} "
                    f"({fmt_min(dt)}, {hop:.0f} m)"
                )
            if dt >= PAUSE_S and hop <= PAUSE_M:
                self.pauses += 1
                self.paused_s += dt
                if dt >= LONG_PAUSE_S:
                    self.events.append(
                        f"parada {local_fmt(t1, self.tz, with_date=False)} "
                        f"{fmt_min(dt)} en {lat1:.5f},{lon1:.5f}"
                    )
                continue
            if dt > 0 and dt <= 12:
                hop_kmh.append(inst_mps * 3.6)
            if inst_mps >= STOP_MPS:
                self.moving_m += hop
                self.moving_s += dt if dt > 0 else 0.0
            elif dt > 0:
                self.paused_s += dt

        if abs(len(self.points) - stored_n) > max(8, stored_n * 0.05):
            self.flags.append("conteo_puntos_desfasado")
        if stored_m >= 400 and self.gps_m >= 400:
            ratio = abs(self.gps_m - stored_m) / max(stored_m, self.gps_m)
            if ratio >= 0.15:
                self.flags.append("distancia_desfasada")
        if stored_m < 200 and self.gps_m < 200:
            self.flags.append("muy_corto")
        if self.teleports:
            self.flags.append(f"teleports:{self.teleports}")
        if self.gaps:
            self.flags.append(f"huecos_gps:{self.gaps}")
        if any(e.startswith("parada ") for e in self.events):
            self.flags.append("parada_larga")
        self.median_dt_s = pct(dt_list, 0.5)
        self.median_acc_m = pct(acc_list, 0.5)
        self.max_acc_m = max(acc_list) if acc_list else None
        if self.median_acc_m is not None and self.median_acc_m > 25:
            self.flags.append("gps_impreciso")
        if hop_kmh:
            self.hop_max_kmh = max(hop_kmh)
            self.hop_p95_kmh = pct(hop_kmh, 0.95)
            if self.hop_max_kmh and self.hop_max_kmh > 220:
                self.flags.append("velocidad_irreal")
        if self.lean_ok == 0:
            self.flags.append("sin_lean")
        elif self.lean_ok / max(self.lean_n, 1) < 0.5:
            self.flags.append("lean_incompleto")
        if leans:
            self.lean_p10 = pct(leans, 0.10)
            self.lean_p50 = pct(leans, 0.50)
            self.lean_p90 = pct(leans, 0.90)
            self.lean_left = -min(leans)
            self.lean_right = max(leans)
            clamped = sum(1 for v in leans if abs(v) >= 69.5)
            self.pct_clamp70 = 100.0 * clamped / len(leans)
            if self.pct_clamp70 >= 8:
                self.flags.append("lean_clamp70")

        # Unique flags, keep order.
        seen: set[str] = set()
        unique: list[str] = []
        for flag in self.flags:
            if flag not in seen:
                seen.add(flag)
                unique.append(flag)
        self.flags = unique

    @property
    def rider(self) -> str:
        return str(self.ride.get("display_name") or "—")

    @property
    def title(self) -> str:
        return str(self.ride.get("title") or "(sin título)")

    @property
    def km_stored(self) -> float:
        return (num(self.ride.get("distance_meters")) or 0.0) / 1000.0

    def row(self) -> dict[str, Any]:
        ride = self.ride
        return {
            "started_local": local_fmt(parse_dt(ride.get("started_at")), self.tz),
            "ended_local": local_fmt(parse_dt(ride.get("ended_at")), self.tz, with_date=False),
            "rider": self.rider,
            "title": self.title,
            "km_stored": round(self.km_stored, 2),
            "km_gps": round(self.gps_m / 1000.0, 2),
            "duration": fmt_min(self.duration_s),
            "moving": fmt_min(self.moving_s),
            "points_stored": int(num(ride.get("point_count")) or 0),
            "points_cloud": len(self.points),
            "avg_kmh_stored": None
            if num(ride.get("avg_speed_mps")) is None
            else round((num(ride.get("avg_speed_mps")) or 0) * 3.6, 1),
            "max_kmh_stored": None
            if num(ride.get("max_speed_mps")) is None
            else round((num(ride.get("max_speed_mps")) or 0) * 3.6, 1),
            "max_kmh_gps": None if self.hop_max_kmh is None else round(self.hop_max_kmh, 1),
            "lean_left": None if self.lean_left is None else round(self.lean_left, 1),
            "lean_right": None if self.lean_right is None else round(self.lean_right, 1),
            "lean_p50": None if self.lean_p50 is None else round(self.lean_p50, 1),
            "median_acc_m": None if self.median_acc_m is None else round(self.median_acc_m, 1),
            "median_dt_s": None if self.median_dt_s is None else round(self.median_dt_s, 2),
            "rodada": ride.get("rodada_title") or "",
            "visibility": ride.get("visibility") or "",
            "ride_id": ride.get("id"),
            "local_id": ride.get("local_id"),
            "flags": ";".join(self.flags),
            "event_notes": " | ".join(self.events),
            "paused_s": round(self.paused_s),
        }


def rides_sql(day: date, tz_name: str, rider: str | None, include_copies: bool) -> str:
    clauses = [
        f"(r.started_at at time zone {sql_lit(tz_name)})::date = {sql_lit(day.isoformat())}::date"
    ]
    if not include_copies:
        clauses.append(f"coalesce(r.local_id, '') not like {sql_lit(COPY_PREFIX + '%')}")
    if rider:
        clauses.append(f"p.display_name ilike {sql_lit('%' + rider + '%')}")
    where = " and ".join(clauses)
    return f"""
select
  r.id::text as id,
  r.user_id::text as user_id,
  r.local_id,
  coalesce(r.title, '') as title,
  r.started_at,
  r.ended_at,
  r.distance_meters,
  r.point_count,
  r.max_speed_mps,
  r.avg_speed_mps,
  r.max_lean_left_deg,
  r.max_lean_right_deg,
  r.line_score,
  r.is_shared,
  r.visibility,
  r.rodada_id::text as rodada_id,
  r.min_lat,
  r.max_lat,
  r.min_lng,
  r.max_lng,
  p.display_name,
  coalesce(rod.title, '') as rodada_title
from public.rides r
join public.profiles p on p.id = r.user_id
left join public.rodadas rod on rod.id = r.rodada_id
where {where}
order by r.started_at;
"""


def points_sql(ride_id: str) -> str:
    return f"""
select
  recorded_at,
  latitude,
  longitude,
  altitude,
  speed_mps,
  accuracy_meters,
  heading,
  lean_degrees,
  pressure_hpa
from public.track_points
where ride_id = {sql_lit(ride_id)}::uuid
order by recorded_at, id;
"""


def rodadas_sql(day: date, tz_name: str) -> str:
    day_lit = sql_lit(day.isoformat())
    tz_lit = sql_lit(tz_name)
    return f"""
select
  rod.id::text as rodada_id,
  rod.title,
  rod.status,
  rod.starts_at,
  host.display_name as host,
  p.display_name as member,
  m.role,
  m.rsvp,
  m.presence,
  (
    select count(*)::int from public.rides r
    where r.rodada_id = rod.id and r.user_id = m.user_id
  ) as linked_rides,
  (
    select coalesce(sum(r.distance_meters), 0) from public.rides r
    where r.rodada_id = rod.id and r.user_id = m.user_id
  ) as linked_meters
from public.rodadas rod
join public.profiles host on host.id = rod.host_id
join public.rodada_members m on m.rodada_id = rod.id
join public.profiles p on p.id = m.user_id
where coalesce(
        (rod.starts_at at time zone {tz_lit})::date,
        (rod.created_at at time zone {tz_lit})::date
      ) = {day_lit}::date
   or rod.id in (
        select r.rodada_id from public.rides r
        where r.rodada_id is not null
          and (r.started_at at time zone {tz_lit})::date = {day_lit}::date
      )
order by rod.starts_at nulls last, rod.title, p.display_name;
"""


def write_gpx(path: Path, analysis: RideAnalysis) -> None:
    name = f"{analysis.rider} — {analysis.title}"
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<gpx version="1.1" creator="RiderLab analyze_day_rides" xmlns="http://www.topografix.com/GPX/1/1">',
        "  <trk>",
        f"    <name>{xml_escape(name)}</name>",
        "    <trkseg>",
    ]
    for pt in analysis.points:
        lat = num(pt.get("latitude"))
        lon = num(pt.get("longitude"))
        if lat is None or lon is None:
            continue
        ele = num(pt.get("altitude"))
        rec = parse_dt(pt.get("recorded_at"))
        lines.append(f'      <trkpt lat="{lat:.7f}" lon="{lon:.7f}">')
        if ele is not None:
            lines.append(f"        <ele>{ele:.1f}</ele>")
        if rec is not None:
            lines.append(f"        <time>{rec.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}</time>")
        lines.append("      </trkpt>")
    lines.extend(["    </trkseg>", "  </trk>", "</gpx>", ""])
    path.write_text("\n".join(lines), encoding="utf-8")


def xml_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def write_points_csv(path: Path, points: list[dict[str, Any]]) -> None:
    fields = [
        "recorded_at",
        "latitude",
        "longitude",
        "altitude",
        "speed_mps",
        "accuracy_meters",
        "heading",
        "lean_degrees",
        "pressure_hpa",
    ]
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for pt in points:
            writer.writerow({k: pt.get(k) for k in fields})


def write_map(path: Path, analyses: list[RideAnalysis], day: date) -> None:
    palette = [
        "#e11d48",
        "#2563eb",
        "#16a34a",
        "#d97706",
        "#7c3aed",
        "#0d9488",
        "#db2777",
        "#4f46e5",
    ]
    riders = []
    seen: set[str] = set()
    for item in analyses:
        if item.rider not in seen:
            seen.add(item.rider)
            riders.append(item.rider)
    color_of = {name: palette[i % len(palette)] for i, name in enumerate(riders)}
    features = []
    for item in analyses:
        coords = []
        for pt in downsample(item.points):
            lat = num(pt.get("latitude"))
            lon = num(pt.get("longitude"))
            if lat is None or lon is None:
                continue
            coords.append([lon, lat])
        if len(coords) < 2:
            continue
        features.append(
            {
                "type": "Feature",
                "properties": {
                    "rider": item.rider,
                    "title": item.title,
                    "color": color_of[item.rider],
                    "km": round(item.gps_m / 1000.0, 2),
                    "started": local_fmt(parse_dt(item.ride.get("started_at")), item.tz),
                    "flags": ", ".join(item.flags),
                },
                "geometry": {"type": "LineString", "coordinates": coords},
            }
        )
    payload = json.dumps({"type": "FeatureCollection", "features": features}, ensure_ascii=False)
    html = f"""<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"/>
  <title>Recorridos {day.isoformat()}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <style>
    html, body, #map {{ height: 100%; margin: 0; }}
    #legend {{
      position: absolute; z-index: 1000; top: 12px; right: 12px;
      background: #fff; padding: 10px 12px; border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,.15); font: 13px/1.4 sans-serif;
      max-width: 260px;
    }}
    .swatch {{ display:inline-block; width:10px; height:10px; margin-right:6px; }}
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="legend"><strong>Recorridos {day.isoformat()}</strong></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    const data = {payload};
    const map = L.map('map');
    const carto = L.tileLayer('https://basemaps.cartocdn.com/dark_all/{{z}}/{{x}}/{{y}}{{r}}.png', {{
      maxZoom: 20, attribution: '&copy; OpenStreetMap &copy; CARTO'
    }});
    const esri = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{{z}}/{{y}}/{{x}}', {{
      maxZoom: 19, attribution: 'Tiles &copy; Esri'
    }});
    carto.addTo(map);
    let switched = false;
    carto.on('tileerror', () => {{
      if (switched) return;
      switched = true;
      map.removeLayer(carto);
      esri.addTo(map);
    }});
    const layers = [];
    const riders = {{}};
    data.features.forEach((f) => {{
      const color = f.properties.color;
      const layer = L.geoJSON(f, {{
        style: {{ color, weight: 4, opacity: 0.85 }}
      }}).bindPopup(
        `<b>${{f.properties.rider}}</b><br>${{f.properties.title}}<br>` +
        `${{f.properties.started}} · ${{f.properties.km}} km` +
        (f.properties.flags ? `<br>${{f.properties.flags}}` : '')
      );
      layer.addTo(map);
      layers.push(layer);
      riders[f.properties.rider] = color;
    }});
    const legend = document.getElementById('legend');
    Object.entries(riders).forEach(([name, color]) => {{
      const row = document.createElement('div');
      row.innerHTML = `<span class="swatch" style="background:${{color}}"></span>${{name}}`;
      legend.appendChild(row);
    }});
    if (layers.length) {{
      const group = L.featureGroup(layers);
      map.fitBounds(group.getBounds().pad(0.08));
    }} else {{
      map.setView([21.0, -101.5], 7);
    }}
  </script>
</body>
</html>
"""
    path.write_text(html, encoding="utf-8")


def write_summary(
    path: Path,
    analyses: list[RideAnalysis],
    day: date,
    tz: ZoneInfo,
    rodada_rows: list[dict[str, Any]] | None = None,
) -> None:
    by_rider: dict[str, list[RideAnalysis]] = defaultdict(list)
    for item in analyses:
        by_rider[item.rider].append(item)
    total_km = sum(item.gps_m for item in analyses) / 1000.0
    stored_km = sum(item.km_stored for item in analyses)
    flagged = [item for item in analyses if item.flags]
    lines = [
        f"# Recorridos {day.isoformat()}",
        "",
        f"Zona horaria: `{tz.key}`. Generado: {datetime.now(tz).strftime('%Y-%m-%d %H:%M')}.",
        "",
        "## Resumen",
        "",
        f"- Riders: **{len(by_rider)}**",
        f"- Recorridos: **{len(analyses)}**",
        f"- Distancia GPS: **{total_km:.2f} km** (nube: {stored_km:.2f} km)",
        f"- Con banderas: **{len(flagged)}**",
        "",
        "### Por rider",
        "",
        "| Rider | Recorridos | km GPS | km nube |",
        "|---|---:|---:|---:|",
    ]
    for rider, items in sorted(by_rider.items(), key=lambda kv: (-sum(i.gps_m for i in kv[1]), kv[0])):
        gps = sum(i.gps_m for i in items) / 1000.0
        stored = sum(i.km_stored for i in items)
        lines.append(f"| {rider} | {len(items)} | {gps:.2f} | {stored:.2f} |")
    if rodada_rows:
        lines += [
            "",
            "## Rodadas",
            "",
            "| Rodada | Inicio | Estado | Miembro | Rol | Recorridos ligados | km |",
            "|---|---|---|---|---|---:|---:|",
        ]
        for row in rodada_rows:
            linked = int(num(row.get("linked_rides")) or 0)
            km = (num(row.get("linked_meters")) or 0) / 1000.0
            mark = "" if linked else " **sin track**"
            lines.append(
                "| {title} | {start} | {status} | {member}{mark} | {role} | {linked} | {km:.2f} |".format(
                    title=str(row.get("title") or "").replace("|", "/"),
                    start=local_fmt(parse_dt(row.get("starts_at")), tz),
                    status=row.get("status") or "",
                    member=row.get("member") or "",
                    mark=mark,
                    role=row.get("role") or "",
                    linked=linked,
                    km=km,
                )
            )
    lines += [
        "",
        "## Recorridos",
        "",
        "| Inicio | Fin | Rider | Título | km GPS | km nube | Duración | Puntos | Lean L/R | Banderas |",
        "|---|---|---|---|---:|---:|---|---:|---|---|",
    ]
    for item in analyses:
        lean = "—"
        if item.lean_left is not None and item.lean_right is not None:
            lean = f"{item.lean_left:.0f}/{item.lean_right:.0f}"
        flags = ", ".join(item.flags) if item.flags else ""
        lines.append(
            "| {start} | {end} | {rider} | {title} | {gps:.2f} | {stored:.2f} | {dur} | {pts} | {lean} | {flags} |".format(
                start=local_fmt(parse_dt(item.ride.get("started_at")), tz),
                end=local_fmt(parse_dt(item.ride.get("ended_at")), tz, with_date=False),
                rider=item.rider,
                title=item.title.replace("|", "/"),
                gps=item.gps_m / 1000.0,
                stored=item.km_stored,
                dur=fmt_min(item.duration_s),
                pts=len(item.points),
                lean=lean,
                flags=flags,
            )
        )
    with_events = [item for item in analyses if item.events]
    if with_events:
        lines += ["", "## Huecos y paradas", ""]
        for item in with_events:
            lines.append(f"### {item.rider} · {item.title}")
            for event in item.events:
                lines.append(f"- {event}")
            lines.append("")
    if flagged:
        lines += ["", "## Problemas", ""]
        for item in flagged:
            lines.append(
                f"- **{item.rider}** · {local_fmt(parse_dt(item.ride.get('started_at')), tz)} · "
                f"{item.title}: {', '.join(item.flags)}"
            )
    lines += [
        "",
        "## Archivos",
        "",
        "- `rides.csv` / `rides.json` — tabla de resumen",
        "- `map.html` — mapa local (necesita red para tiles OSM)",
        "- `tracks/<ride_id>.gpx` y `.csv` — GPS completo por recorrido",
        "",
        "Volver a correr:",
        "",
        "```bash",
        f"python supabase/scripts/analyze_day_rides.py --date {day.isoformat()}",
        "```",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def load_zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except Exception:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "tzdata"],
            check=False,
            capture_output=True,
            text=True,
        )
        try:
            return ZoneInfo(name)
        except Exception as exc:
            raise SystemExit(
                f"No se encontró la zona {name}. Instala tzdata: python -m pip install tzdata"
            ) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Descarga y analiza recorridos de un día (hora México).")
    parser.add_argument("--date", default="today", help="YYYY-MM-DD o today (default: today)")
    parser.add_argument("--tz", default=TZ_DEFAULT, help=f"IANA timezone (default: {TZ_DEFAULT})")
    parser.add_argument("--rider", default="", help="Filtro substring del display_name")
    parser.add_argument("--include-copies", action="store_true", help="Incluir local_id copy-from-*")
    parser.add_argument("--skip-points", action="store_true", help="Solo metadatos, no descarga GPS")
    parser.add_argument("--out", default="", help="Carpeta de salida (default: tmp/ride-analysis/<date>)")
    return parser.parse_args()


def resolve_day(raw: str, tz: ZoneInfo) -> date:
    text = raw.strip().lower()
    if text in {"today", "hoy", ""}:
        return datetime.now(tz).date()
    if text in {"yesterday", "ayer"}:
        return datetime.now(tz).date() - timedelta(days=1)
    if not DATE_RE.match(raw.strip()):
        raise SystemExit(f"fecha inválida: {raw} (usa YYYY-MM-DD, today o yesterday)")
    y, m, d = map(int, raw.strip().split("-"))
    return date(y, m, d)


def main() -> int:
    args = parse_args()
    tz = load_zone(args.tz)
    day = resolve_day(args.date, tz)
    out_dir = Path(args.out) if args.out else REPO / "tmp" / "ride-analysis" / day.isoformat()
    tracks_dir = out_dir / "tracks"
    out_dir.mkdir(parents=True, exist_ok=True)
    tracks_dir.mkdir(parents=True, exist_ok=True)

    print(f"Consultando recorridos del {day.isoformat()} ({tz.key})...")
    rides = db_query(rides_sql(day, args.tz, args.rider.strip() or None, args.include_copies))
    print(f"  {len(rides)} recorrido(s).")
    rodada_rows: list[dict[str, Any]] = []
    if not args.rider.strip():
        rodada_rows = db_query(rodadas_sql(day, args.tz))
        if rodada_rows:
            print(f"  {len({row.get('rodada_id') for row in rodada_rows})} rodada(s).")
    analyses: list[RideAnalysis] = []
    for i, ride in enumerate(rides, 1):
        ride_id = str(ride.get("id") or "")
        rider = ride.get("display_name") or "?"
        title = ride.get("title") or ""
        print(f"  [{i}/{len(rides)}] {rider} {local_fmt(parse_dt(ride.get('started_at')), tz)} {title}")
        points: list[dict[str, Any]] = []
        if not args.skip_points and ride_id:
            points = db_query(points_sql(ride_id))
            print(f"      {len(points)} puntos GPS")
        item = RideAnalysis(ride=ride, points=points, tz=tz)
        item.analyze()
        analyses.append(item)
        if points:
            write_gpx(tracks_dir / f"{ride_id}.gpx", item)
            write_points_csv(tracks_dir / f"{ride_id}.csv", points)

    rows = [item.row() for item in analyses]
    (out_dir / "rides.json").write_text(
        json.dumps(
            {
                "date": day.isoformat(),
                "tz": args.tz,
                "count": len(analyses),
                "rides": rows,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    if rows:
        with (out_dir / "rides.csv").open("w", encoding="utf-8", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
    else:
        (out_dir / "rides.csv").write_text("", encoding="utf-8")
    write_summary(out_dir / "summary.md", analyses, day, tz, rodada_rows)
    write_map(out_dir / "map.html", analyses, day)

    print("")
    print(f"Listo: {out_dir}")
    print(f"  - {out_dir / 'summary.md'}")
    print(f"  - {out_dir / 'map.html'}")
    if not analyses:
        print("No hubo recorridos en esa fecha.")
        return 0
    print("")
    print(f"{'Inicio':<17} {'Rider':<18} {'km GPS':>7} {'Puntos':>7}  Título")
    for item in analyses:
        start = local_fmt(parse_dt(item.ride.get("started_at")), tz)
        print(
            f"{start:<17} {item.rider[:18]:<18} {item.gps_m/1000:7.2f} {len(item.points):7d}  {item.title}"
        )
        if item.flags:
            print(f"{'':17} banderas: {', '.join(item.flags)}")
        for event in item.events:
            print(f"{'':17} {event}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as exc:  # noqa: BLE001 — CLI tool, print and stop
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
