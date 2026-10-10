#!/usr/bin/env python3
"""RiderLab — corrección diferencial por posición (ancla) + perfil de altura.

Entrada: carpetas de sesión del logger (SD /riderlab/sessions/<id>/) del ANCLA
(estática en un punto marcado) y de la MOTO (rider). Solo stdlib (Windows ok).

Posición:  err_ancla(t) = pos_ancla(t) - (REF + ANT_H)
           moto_corr(t) = moto(t) - suavizado(err_ancla)(t)
           Solo cancela error COMÚN: mismo receptor/config y satélites comunes.
Altura:    barometría diferencial  dh = (Rd*T/g) * ln(p_ancla / (p_moto - dp_coloc))
           h_baro = h_sensor_ancla + dh ; fusión complementaria con GPS
           h_fus  = h_baro + LP_tau(h_gps_corr - h_baro)

Uso:
  python tools/anchor_correct.py --anchor SES_ANCLA --rider SES_MOTO --out salida
  python tools/anchor_correct.py --rider SES_MOTO --out salida      (solo deriva)
Ver --help y hardware/firmware/ANCHOR.md.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import datetime as dt
import json
import math
import os
import statistics
import sys
from xml.sax.saxutils import escape

GPS_EPOCH = dt.datetime(1980, 1, 6, tzinfo=dt.timezone.utc)
LEAP_S = 18  # GPS-UTC (vigente desde 2017)
RD = 287.05
G0 = 9.80665
WEEK_S = 604800.0


# ----------------------------------------------------------------- utilidades
def read_ndjson(path):
    """Lee NDJSON tolerando la última línea truncada (corte de energía)."""
    out = []
    if not os.path.exists(path):
        return out
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def read_json(path):
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.loads(f.read().strip().split("\n")[0])
    except (json.JSONDecodeError, IndexError):
        return None


class LocalFrame:
    """Plano tangente local (mismo modelo que el firmware)."""

    def __init__(self, lat0, lon0, h0):
        a, f = 6378137.0, 1 / 298.257223563
        e2 = f * (2 - f)
        s = math.sin(math.radians(lat0))
        w = math.sqrt(1 - e2 * s * s)
        self.rn = a / w
        self.rm = a * (1 - e2) / w ** 3
        self.lat0, self.lon0, self.h0 = lat0, lon0, h0
        self.cos = math.cos(math.radians(lat0))

    def enu(self, lat, lon, h):
        n = math.radians(lat - self.lat0) * (self.rm + self.h0)
        e = math.radians(lon - self.lon0) * (self.rn + self.h0) * self.cos
        return e, n, h - self.h0

    def llh(self, e, n, u):
        lat = self.lat0 + math.degrees(n / (self.rm + self.h0))
        lon = self.lon0 + math.degrees(e / ((self.rn + self.h0) * self.cos))
        return lat, lon, self.h0 + u


def interp(ts, vs, t, max_gap=None):
    """Interpolación lineal en series ordenadas; None fuera de rango / hueco."""
    if not ts:
        return None
    i = bisect.bisect_left(ts, t)
    if i < len(ts) and ts[i] == t:
        return vs[i]
    if i == 0 or i == len(ts):
        return None
    t0, t1 = ts[i - 1], ts[i]
    if max_gap is not None and t1 - t0 > max_gap:
        return None
    v0, v1 = vs[i - 1], vs[i]
    if v0 is None or v1 is None:
        return None
    w = (t - t0) / (t1 - t0)
    return v0 + (v1 - v0) * w


def moving_average(ts, vs, window_s, min_frac=0.0):
    """Media móvil centrada (no causal) en tiempo irregular, O(n)."""
    out = [None] * len(ts)
    if not ts:
        return out
    half = window_s / 2.0
    lo = hi = 0
    acc = 0.0
    cnt = 0
    dt_med = statistics.median([b - a for a, b in zip(ts, ts[1:])]) if len(ts) > 1 else 1.0
    expected = max(1.0, window_s / max(dt_med, 1e-3))
    for i, t in enumerate(ts):
        while hi < len(ts) and ts[hi] <= t + half:
            if vs[hi] is not None:
                acc += vs[hi]
                cnt += 1
            hi += 1
        while ts[lo] < t - half:
            if vs[lo] is not None:
                acc -= vs[lo]
                cnt -= 1
            lo += 1
        if cnt > 0 and cnt >= min_frac * expected:
            out[i] = acc / cnt
    return out


def rms(vals):
    vals = [v for v in vals if v is not None]
    return math.sqrt(sum(v * v for v in vals) / len(vals)) if vals else None


def fmt(v, nd=3):
    return "" if v is None or (isinstance(v, float) and math.isnan(v)) else f"{v:.{nd}f}"


# ----------------------------------------------------------------- sesiones
class Session:
    def __init__(self, path, name):
        self.path = path
        self.name = name
        self.manifest = read_json(os.path.join(path, "manifest.json")) or {}
        self.summary = read_json(os.path.join(path, "anchor_summary.json"))
        self.pvt_raw = read_ndjson(os.path.join(path, "pvt.ndjson"))
        self.gnss_raw = read_ndjson(os.path.join(path, "gnss.ndjson")) if not self.pvt_raw else []
        self.sat_raw = read_ndjson(os.path.join(path, "sat.ndjson"))
        self.baro_raw = read_ndjson(os.path.join(path, "baro.ndjson"))
        self.marks_raw = read_ndjson(os.path.join(path, "marks.ndjson"))
        self.aerr_raw = read_ndjson(os.path.join(path, "anchor_err.ndjson"))
        self.legacy = not self.pvt_raw
        self.epochs = []  # dicts with t, lat, lon, h, msl, hacc, vacc, sv, fix, ok, gs
        self.week = None
        self.tmap = None  # (a, b): t = a*t_us + b

    @property
    def role(self):
        return self.manifest.get("role", "rider")

    def build(self, time_base):
        """time_base: 'gps' (semana+tow) o 'sod' (segundo UTC del día)."""
        eps = []
        if not self.legacy:
            for r in self.pvt_raw:
                try:
                    tow = float(r["tow"]) / 1000.0
                except (KeyError, ValueError, TypeError):
                    continue
                utc = parse_utc(r.get("utc"), r.get("ns", 0))
                if time_base == "gps":
                    if utc is not None:
                        approx = (utc - GPS_EPOCH).total_seconds() + LEAP_S
                        week = round((approx - tow) / WEEK_S)
                        self.week = week
                    week = self.week if self.week is not None else 0
                    t = week * WEEK_S + tow
                else:
                    if utc is None:
                        continue
                    t = utc.hour * 3600 + utc.minute * 60 + utc.second + utc.microsecond / 1e6
                eps.append(dict(
                    t=t, tow=tow, utc=utc, t_us=r.get("t_us"), lat=r.get("lat"), lon=r.get("lon"),
                    h=r.get("h"), msl=r.get("msl"), hacc=r.get("hacc", 99), vacc=r.get("vacc", 99),
                    sv=r.get("sv", 0), fix=r.get("fix", 0), ok=r.get("ok", 0) and not r.get("inv", 0),
                    gs=r.get("gs", 0.0), pdop=r.get("pdop")))
        else:
            for r in self.gnss_raw:
                if "utc_ms" not in r:
                    continue
                t = r["utc_ms"] / 1000.0
                acc = r.get("acc_m", -1)
                eps.append(dict(
                    t=t, tow=None, utc=None, t_us=r.get("t_us"), lat=r.get("lat"), lon=r.get("lng"),
                    h=r.get("alt"), msl=r.get("alt"), hacc=acc if acc and acc > 0 else 2.5, vacc=5.0,
                    sv=r.get("sats", 0), fix=3, ok=1, gs=r.get("speed_mps", 0.0), pdop=r.get("hdop")))
        eps.sort(key=lambda e: e["t"])
        # dedupe identical t
        ded = []
        for e in eps:
            if ded and abs(ded[-1]["t"] - e["t"]) < 1e-6:
                continue
            ded.append(e)
        self.epochs = ded
        self._fit_timemap()
        self.time_base = time_base

    def _fit_timemap(self):
        pts = [(e["t_us"], e["t"]) for e in self.epochs if e.get("t_us") is not None]
        if len(pts) < 2:
            return
        n = len(pts)
        mx = sum(p[0] for p in pts) / n
        my = sum(p[1] for p in pts) / n
        sxx = sum((p[0] - mx) ** 2 for p in pts)
        if sxx <= 0:
            return
        a = sum((p[0] - mx) * (p[1] - my) for p in pts) / sxx
        b = my - a * mx
        self.tmap = (a, b)

    def t_from(self, rec):
        """Tiempo de un registro con 'tow' (ms) o, si falta, vía t_us."""
        tow = rec.get("tow")
        if tow is not None and tow >= 0:
            tow_s = float(tow) / 1000.0
            if self.time_base == "gps":
                week = self.week if self.week is not None else 0
                t = week * WEEK_S + tow_s
                # cruce de semana dentro de la sesión
                if self.epochs and t < self.epochs[0]["t"] - WEEK_S / 2:
                    t += WEEK_S
                return t
            if self.tmap and rec.get("t_us") is not None:
                return self.tmap[0] * rec["t_us"] + self.tmap[1]
            return None
        if self.tmap and rec.get("t_us") is not None:
            return self.tmap[0] * rec["t_us"] + self.tmap[1]
        return None

    def sats(self):
        out = []
        for r in self.sat_raw:
            t = self.t_from(r)
            if t is None:
                continue
            used = frozenset((s[0], s[1]) for s in r.get("sv", []) if len(s) >= 6 and (s[5] & 0x08))
            out.append((t, used))
        out.sort(key=lambda x: x[0])
        return out

    def baro(self):
        out = []
        for r in self.baro_raw:
            pa = r.get("pa")
            if pa is None and r.get("hpa") is not None:
                pa = r["hpa"] * 100.0
            if pa is None:
                continue
            t = self.t_from(r)
            if t is None:
                continue
            out.append((t, float(pa), r.get("temp_c")))
        out.sort(key=lambda x: x[0])
        return out

    def marks(self):
        out = []
        for r in self.marks_raw:
            t = self.t_from(r)
            out.append(dict(t=t, kind=r.get("kind", ""), v=r.get("v"), note=r.get("note", "")))
        return out


def parse_utc(s, ns):
    if not s:
        return None
    try:
        d = dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=dt.timezone.utc)
    except ValueError:
        return None
    if d.year < 2020:
        return None
    return d + dt.timedelta(microseconds=(ns or 0) / 1000.0)


def good(e, max_hacc, min_sv):
    return (e["fix"] == 3 and e["ok"] and e["lat"] is not None and e["hacc"] is not None
            and e["hacc"] <= max_hacc and e["sv"] >= min_sv)


# ----------------------------------------------------------------- referencia
def resolve_ref(args, anchor):
    """Devuelve dict(lat, lon, h, htype, source, sigma, id, ant_h, absolute)."""
    ant_h = args.ant_h
    if ant_h is None and anchor is not None:
        ant_h = anchor.manifest.get("ant_h_m")
    ant_h = float(ant_h or 0.0)
    if args.ref:
        parts = args.ref.split(",")
        lat, lon, h = float(parts[0]), float(parts[1]), float(parts[2])
        htype = parts[3].strip().lower() if len(parts) > 3 else "ell"
        return dict(lat=lat, lon=lon, h=h, htype=htype, source="cli", sigma=None, id="cli",
                    ant_h=ant_h, absolute=True)
    for src in (anchor.manifest.get("ref") if anchor else None,
                (anchor.summary or {}).get("ref") if anchor else None):
        if src:
            return dict(lat=src["lat"], lon=src["lon"], h=src["h"],
                        htype=src.get("h_type", "ell"), source=src.get("source", "?"),
                        sigma=src.get("sigma_m"), id=src.get("id", "?"), ant_h=ant_h,
                        absolute=src.get("source", "") not in ("avg", "mean", ""))
    if anchor is not None:
        g = [e for e in anchor.epochs if good(e, args.max_hacc, args.min_sv)]
        if g:
            lat = statistics.median(e["lat"] for e in g)
            lon = statistics.median(e["lon"] for e in g)
            h = statistics.median(e["h"] for e in g) - ant_h
            return dict(lat=lat, lon=lon, h=h, htype="ell", source="mean", sigma=None,
                        id="anchor-mean", ant_h=ant_h, absolute=False)
    return None


def hfield(ref):
    return "msl" if ref and ref.get("htype") == "msl" else "h"


# ----------------------------------------------------------------- posición
def anchor_error_series(anchor, ref, frame, args):
    """err(t) del ancla en E/N/U respecto a REF+ANT_H; excluye golpes."""
    hf = hfield(ref)
    dist = set()
    for r in anchor.aerr_raw:
        if r.get("dist"):
            dist.add(round(float(r["tow"]) / 1000.0, 2))
    ts, ee, nn, uu = [], [], [], []
    ref_ant = frame.enu(ref["lat"], ref["lon"], ref["h"] + ref["ant_h"])
    dropped = 0
    for e in anchor.epochs:
        if not good(e, args.max_hacc, args.min_sv):
            dropped += 1
            continue
        if e["tow"] is not None and round(e["tow"], 2) in dist:
            dropped += 1
            continue
        x = frame.enu(e["lat"], e["lon"], e[hf])
        ts.append(e["t"])
        ee.append(x[0] - ref_ant[0])
        nn.append(x[1] - ref_ant[1])
        uu.append(x[2] - ref_ant[2])
    se = moving_average(ts, ee, args.smooth_s, 0.5)
    sn = moving_average(ts, nn, args.smooth_s, 0.5)
    su = moving_average(ts, uu, args.smooth_s, 0.5)
    return dict(t=ts, e=se, n=sn, u=su, raw=(ee, nn, uu), dropped=dropped)


def sat_overlap(rider_sats, anchor_sats, t):
    def nearest(lst, t):
        if not lst:
            return None
        keys = [x[0] for x in lst]
        i = bisect.bisect_left(keys, t)
        best = None
        for j in (i - 1, i):
            if 0 <= j < len(lst) and abs(lst[j][0] - t) <= 1.6:
                if best is None or abs(lst[j][0] - t) < abs(best[0] - t):
                    best = lst[j]
        return best
    r = nearest(rider_sats, t)
    a = nearest(anchor_sats, t)
    if r is None or a is None or not r[1]:
        return None, None
    common = len(r[1] & a[1])
    return common, common / len(r[1])


def static_windows(eps, frame, args, marks=None):
    """Ventanas estáticas (vel < umbral >= N s). Marca si están cerca del REF."""
    wins = []
    cur = []
    for e in eps:
        if e["gs"] is not None and e["gs"] < args.static_speed:
            cur.append(e)
        else:
            if cur and cur[-1]["t"] - cur[0]["t"] >= args.static_min_s:
                wins.append(cur)
            cur = []
    if cur and cur[-1]["t"] - cur[0]["t"] >= args.static_min_s:
        wins.append(cur)
    out = []
    for w in wins:
        es = [frame.enu(e["lat"], e["lon"], 0)[:2] for e in w]
        me = statistics.median(x[0] for x in es)
        mn = statistics.median(x[1] for x in es)
        out.append(dict(t0=w[0]["t"], t1=w[-1]["t"], near_ref=math.hypot(me, mn) <= args.coloc_radius,
                        src="speed"))
    # COLOC explícito (botón C largo / serial)
    if marks:
        start = None
        for m in marks:
            if m["t"] is None:
                continue
            if m["kind"] == "coloc_start":
                start = m["t"]
            elif m["kind"] == "coloc_end" and start is not None:
                out.append(dict(t0=start, t1=m["t"], near_ref=True, src="mark"))
                start = None
    marked = [w for w in out if w["src"] == "mark"]
    if marked:
        out = [w for w in out if w["src"] == "mark" or not any(
            w["t0"] <= m["t1"] and m["t0"] <= w["t1"] for m in marked)]
    out.sort(key=lambda w: w["t0"])
    return out


# ----------------------------------------------------------------- vueltas
def auto_gate(rows, args):
    moving = [r for r in rows if r["speed"] is not None and r["speed"] > 2.0]
    if len(moving) < 50:
        return None
    cell = 10.0
    passes = {}
    last_t = {}
    for r in moving:
        k = (math.floor(r["e"] / cell), math.floor(r["n"] / cell))
        if k not in last_t or r["t"] - last_t[k] > 30.0:
            passes[k] = passes.get(k, 0) + 1
        last_t[k] = r["t"]
    best = max(passes.items(), key=lambda kv: kv[1])
    if best[1] < 2:
        return None
    k = best[0]
    return ((k[0] + 0.5) * cell, (k[1] + 0.5) * cell, 12.0)


def split_laps(rows, gate, args):
    if gate is None:
        return []
    ge, gn, rad = gate
    passes = []
    inside = None
    for i, r in enumerate(rows):
        d = math.hypot(r["e"] - ge, r["n"] - gn)
        if d <= rad and r["speed"] is not None and r["speed"] > 1.0:
            if inside is None or d < inside[1]:
                inside = (i, d)
        elif inside is not None:
            passes.append(inside[0])
            inside = None
    if inside is not None:
        passes.append(inside[0])
    laps = []
    for a, b in zip(passes, passes[1:]):
        length = rows[b]["dist"] - rows[a]["dist"]
        if length >= args.min_lap_m:
            laps.append((a, b))
    return laps


def climb_descent(vals, hyst):
    """Ascenso/descenso total con histéresis (evita acumular ruido)."""
    vals = [v for v in vals if v is not None]
    if not vals:
        return 0.0, 0.0
    up = down = 0.0
    ref = vals[0]
    for v in vals[1:]:
        if v - ref >= hyst:
            up += v - ref
            ref = v
        elif ref - v >= hyst:
            down += ref - v
            ref = v
    return up, down


# ----------------------------------------------------------------- altura
def baro_vertical(rider, anchor, rows, ref, ref_h_field, args, report):
    """Calcula h_baro por fila (barometría diferencial si hay ancla)."""
    rb = rider.baro()
    if not rb:
        report["baro"] = {"mode": "none", "why": "moto sin baro.ndjson"}
        return None
    ab = anchor.baro() if anchor is not None else []
    rt = [x[0] for x in rb]
    rp = [x[1] for x in rb]
    if args.baro_lp_s > 0:
        rp = [v if v is not None else None for v in moving_average(rt, rp, args.baro_lp_s)]
    info = {}
    # temperatura del aire para la escala hipsométrica
    if args.air_temp_c is not None:
        tair = args.air_temp_c
        info["air_temp_src"] = "cli"
    else:
        temps = [x[2] for x in (ab or rb) if x[2] is not None]
        tair = statistics.median(temps) if temps else 15.0
        tair = max(-10.0, min(40.0, tair))
        info["air_temp_src"] = "sensor ancla (die temp, aprox.)" if ab else "sensor moto (aprox.)"
    tk = tair + 273.15
    scale = RD * tk / G0
    info["air_temp_c"] = round(tair, 2)
    if ab:
        at = [x[0] for x in ab]
        ap = moving_average(at, [x[1] for x in ab], args.anchor_baro_smooth_s)
        # co-location: moto junto al ancla (marcas COLOC o estáticos cerca del REF)
        wins = report.get("_coloc_windows", [])
        offs = []
        for w in wins:
            d = []
            for t, p in zip(rt, rp):
                if w["t0"] + 5 <= t <= w["t1"] - 5 and p is not None:
                    pa = interp(at, ap, t, 2.0)
                    if pa is not None:
                        d.append(p - pa)
            if len(d) >= 10:
                offs.append(((w["t0"] + w["t1"]) / 2, statistics.median(d), len(d), w["src"]))
        # Durante la co-location los sensores no están a la misma altura (moto
        # ~rider_ant_h, ancla ~ANT_H): quitar esa diferencia hidrostática.
        h_anchor_sensor = args.anchor_baro_h if args.anchor_baro_h is not None else ref["ant_h"]
        dh_coloc = (args.rider_ant_h or 0.0) - h_anchor_sensor
        pa_ref = statistics.median(ap[i] for i in range(len(ap)) if ap[i] is not None) if ap else 101325.0
        hydro = pa_ref * (math.exp(-dh_coloc / scale) - 1.0)
        offs = [(t, d - hydro, n, src) for (t, d, n, src) in offs]
        info["coloc_dh_m"] = round(dh_coloc, 3)
        info["coloc_hydro_pa"] = round(hydro, 2)
        if args.baro_offset_pa is not None:
            offs = [(0.0, args.baro_offset_pa, 0, "cli")]
        info["coloc"] = [{"t": round(o[0], 1), "dp_pa": round(o[1], 2), "n": o[2], "src": o[3]}
                         for o in offs]
        if not offs:
            info["warning"] = ("sin co-location (moto junto al ancla) -> offset de sensores = 0; "
                               "error típico BMP280 entre unidades hasta ±1 hPa (~8 m)")

        def dp_at(t):
            if not offs:
                return 0.0
            if len(offs) == 1 or t <= offs[0][0]:
                return offs[0][1]
            if t >= offs[-1][0]:
                return offs[-1][1]
            return interp([o[0] for o in offs], [o[1] for o in offs], t)

        h_sensor = ref["h"] + (args.anchor_baro_h if args.anchor_baro_h is not None else ref["ant_h"])
        hb_t, hb_v = [], []
        for t, p in zip(rt, rp):
            pa = interp(at, ap, t, 2.0)
            if pa is None or p is None:
                continue
            pc = p - dp_at(t)
            hb_t.append(t)
            hb_v.append(h_sensor + scale * math.log(pa / pc) - (args.rider_ant_h or 0.0))
        info["mode"] = "diferencial"
    else:
        hb_t, hb_v = [], []
        for t, p in zip(rt, rp):
            if p is None:
                continue
            hb_t.append(t)
            hb_v.append(44330.77 * (1 - (p / 101325.0) ** 0.190263) - (args.rider_ant_h or 0.0))
        info["mode"] = "solo-moto (sin ancla: deriva del clima corregida solo por la fusión GPS)"
    info["n"] = len(hb_v)
    report["baro"] = info
    if not hb_v:
        return None
    return hb_t, hb_v, scale


# ----------------------------------------------------------------- principal
def process(args):
    rider = Session(args.rider, "rider")
    anchor = Session(args.anchor, "anchor") if args.anchor else None
    base = "gps" if (not rider.legacy and (anchor is None or not anchor.legacy)) else "sod"
    rider.build(base)
    if anchor is not None:
        anchor.build(base)
    report = {"tool": "anchor_correct.py v1", "time_base": base, "rider": args.rider,
              "anchor": args.anchor, "warnings": []}
    if rider.legacy:
        report["warnings"].append("moto sin pvt.ndjson: uso gnss.ndjson (sin hAcc real ni NAV-SAT)")
    if anchor is not None and anchor.legacy:
        report["warnings"].append("ancla sin pvt.ndjson: uso gnss.ndjson")
    if anchor is not None:
        ra, rr = anchor.manifest.get("receiver", {}), rider.manifest.get("receiver", {})
        if ra and rr and ra.get("profile") != rr.get("profile"):
            report["warnings"].append(f"perfil de receptor distinto: ancla={ra.get('profile')} "
                                      f"moto={rr.get('profile')} (la corrección no cancela)")
        for k, r in (("ancla", ra), ("moto", rr)):
            if r and r.get("cfg") not in ("ok", None):
                report["warnings"].append(f"{k}: receptor cfg={r.get('cfg')} (perfil no aplicado)")
    ref = resolve_ref(args, anchor)
    if ref is None:
        # sin ancla ni REF: origen = mediana de la moto (solo forma/relativo)
        g = [e for e in rider.epochs if good(e, args.max_hacc, args.min_sv)]
        if not g:
            raise SystemExit("sin épocas válidas en la moto")
        ref = dict(lat=statistics.median(e["lat"] for e in g), lon=statistics.median(e["lon"] for e in g),
                   h=statistics.median(e["h"] for e in g), htype="ell", source="rider-median",
                   sigma=None, id="rider-median", ant_h=0.0, absolute=False)
    report["ref"] = {k: ref[k] for k in ("id", "lat", "lon", "h", "htype", "source", "sigma",
                                         "ant_h", "absolute")}
    hf = hfield(ref)
    frame = LocalFrame(ref["lat"], ref["lon"], ref["h"])
    rider_ant = args.rider_ant_h or 0.0

    aerr = anchor_error_series(anchor, ref, frame, args) if anchor is not None else None
    if aerr:
        report["anchor"] = {"epochs_used": len(aerr["t"]), "epochs_dropped": aerr["dropped"],
                            "smooth_s": args.smooth_s,
                            "err_rms_m": {"e": fmt(rms(aerr["raw"][0])), "n": fmt(rms(aerr["raw"][1])),
                                          "u": fmt(rms(aerr["raw"][2]))}}
    asats = anchor.sats() if anchor is not None else []
    rsats = rider.sats()
    rmarks = rider.marks()

    # filas de la moto
    total = len(rider.epochs)
    rows = []
    for e in rider.epochs:
        if not good(e, args.max_hacc, args.min_sv):
            continue
        x = frame.enu(e["lat"], e["lon"], e[hf] - rider_ant)
        rows.append(dict(t=e["t"], utc=e["utc"], lat_raw=e["lat"], lon_raw=e["lon"], e_raw=x[0],
                         n_raw=x[1], u_raw=x[2], speed=e["gs"], hacc=e["hacc"], vacc=e["vacc"],
                         sv=e["sv"]))
    report["rider_epochs"] = {"total": total, "kept": len(rows), "dropped_bad_fix": total - len(rows),
                              "max_hacc": args.max_hacc, "min_sv": args.min_sv}
    if not rows:
        raise SystemExit("sin épocas válidas en la moto (hAcc/sat)")

    # estáticos (validación + deriva + co-location baro)
    wins = static_windows([e for e in rider.epochs if good(e, args.max_hacc, args.min_sv)],
                          frame, args, rmarks)
    ref_wins = [w for w in wins if w["near_ref"]]
    report["_coloc_windows"] = ref_wins
    # deriva lineal: sesgo de la moto en estáticos sobre el punto
    drift_pts = []
    for w in ref_wins:
        sel = [r for r in rows if w["t0"] <= r["t"] <= w["t1"]]
        if len(sel) >= 10:
            drift_pts.append(((w["t0"] + w["t1"]) / 2,
                              statistics.median(r["e_raw"] for r in sel),
                              statistics.median(r["n_raw"] for r in sel),
                              statistics.median(r["u_raw"] for r in sel)))

    def drift_at(t):
        if not drift_pts:
            return None
        if len(drift_pts) == 1:
            return drift_pts[0][1:]
        ts = [p[0] for p in drift_pts]
        if t <= ts[0]:
            return drift_pts[0][1:]
        if t >= ts[-1]:
            return drift_pts[-1][1:]
        return tuple(interp(ts, [p[k] for p in drift_pts], t) for k in (1, 2, 3))

    poor = 0
    modes = {}
    for r in rows:
        corr = None
        mode = "raw"
        flag = ""
        common = overlap = None
        if aerr and args.mode in ("auto", "anchor"):
            ce = interp(aerr["t"], aerr["e"], r["t"], 2.0)
            cn = interp(aerr["t"], aerr["n"], r["t"], 2.0)
            cu = interp(aerr["t"], aerr["u"], r["t"], 2.0)
            if ce is not None and cn is not None and cu is not None:
                common, overlap = sat_overlap(rsats, asats, r["t"])
                lowsat = overlap is not None and (overlap < args.min_overlap or common < args.min_common)
                if lowsat:
                    poor += 1
                    flag = "pocos_sat_comunes"
                if not (lowsat and args.poor_overlap == "fallback"):
                    corr = (ce, cn, cu)
                    mode = "anchor"
                if overlap is None:
                    flag = flag or "sat_desconocido"
        if corr is None and args.mode in ("auto", "drift"):
            d = drift_at(r["t"])
            if d is not None:
                corr = d
                mode = "drift"
        if corr is None:
            corr = (0.0, 0.0, 0.0)
        r["e"] = r["e_raw"] - corr[0]
        r["n"] = r["n_raw"] - corr[1]
        r["u_gps"] = r["u_raw"] - corr[2]
        r["mode"] = mode
        r["flag"] = flag
        r["common"] = common
        r["overlap"] = overlap
        lat, lon, _ = frame.llh(r["e"], r["n"], 0)
        r["lat"], r["lon"] = lat, lon
        modes[mode] = modes.get(mode, 0) + 1
    report["correction"] = {"modes": modes, "poor_overlap_epochs": poor,
                            "min_overlap": args.min_overlap, "min_common": args.min_common,
                            "drift_points": len(drift_pts)}
    # segmentos con pocos satélites comunes
    segs = []
    cur = None
    for r in rows:
        if r["flag"] == "pocos_sat_comunes":
            if cur is None:
                cur = [r["t"], r["t"]]
            cur[1] = r["t"]
        elif cur is not None:
            segs.append(cur)
            cur = None
    if cur:
        segs.append(cur)
    report["correction"]["poor_overlap_segments"] = [
        {"t0": round(a, 1), "t1": round(b, 1), "dur_s": round(b - a, 1)} for a, b in segs]

    # validación en estáticos sobre el punto
    val = []
    for w in ref_wins:
        sel = [r for r in rows if w["t0"] <= r["t"] <= w["t1"]]
        if len(sel) < 10:
            continue
        val.append({"t0": round(w["t0"], 1), "t1": round(w["t1"], 1), "src": w["src"], "n": len(sel),
                    "rms_h_raw_m": fmt(rms([math.hypot(r["e_raw"], r["n_raw"]) for r in sel])),
                    "rms_h_corr_m": fmt(rms([math.hypot(r["e"], r["n"]) for r in sel])),
                    "rms_u_raw_m": fmt(rms([r["u_raw"] for r in sel])),
                    "rms_u_corr_m": fmt(rms([r["u_gps"] for r in sel])),
                    "in_sample": all(r["mode"] == "drift" for r in sel)})
    report["static_validation"] = val
    report["static_validation_note"] = ("estáticos de la moto sobre/junto al punto; la moto no está "
                                        f"exactamente en la marca (radio {args.coloc_radius} m), "
                                        "el RMS incluye esa separación. 'in_sample' = la deriva se "
                                        "estimó con ese mismo tramo (no es validación independiente).")

    # distancia acumulada (solo en movimiento)
    dist = 0.0
    prev = None
    for r in rows:
        if prev is not None and r["speed"] is not None and r["speed"] > 1.0:
            dist += math.hypot(r["e"] - prev["e"], r["n"] - prev["n"])
        r["dist"] = dist
        prev = r

    # ---------------- vertical
    hb = baro_vertical(rider, anchor, rows, ref, hf, args, report)
    gps_t = [r["t"] for r in rows]
    gps_h = [frame.h0 + r["u_gps"] for r in rows]
    gps_h_s = moving_average(gps_t, gps_h, 2.0)
    q_equiv = []
    if hb:
        hb_t, hb_v, scale = hb
        for r in rows:
            r["h_baro"] = interp(hb_t, hb_v, r["t"], 1.0)
        # presión dinámica: q/(rho g) en metros equivalentes
        for r in rows:
            v = r["speed"] or 0.0
            q_equiv.append(0.5 * v * v / G0)  # q/(rho*g) = v^2/(2g)
        # ajuste k (h_gps - h_baro = c + k*q/(rho g))
        xs, ys = [], []
        for r, qe, hg in zip(rows, q_equiv, gps_h_s):
            if r["h_baro"] is not None and hg is not None:
                xs.append(qe)
                ys.append(hg - r["h_baro"])
        kfit = None
        if len(xs) > 50 and max(xs) - min(xs) > 0.5:
            mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
            sxx = sum((x - mx) ** 2 for x in xs)
            if sxx > 0:
                kfit = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
        report["baro"]["dyn_k_fit"] = fmt(kfit, 3)
        k = 0.0
        if args.dyn_coef == "auto":
            k = kfit or 0.0
        elif args.dyn_coef not in (None, "", "0"):
            k = float(args.dyn_coef)
        report["baro"]["dyn_k_applied"] = k
        for r, qe in zip(rows, q_equiv):
            r["dyn_flag"] = 1 if (r["speed"] or 0) > args.baro_max_speed else 0
            if r["h_baro"] is not None and k:
                r["h_baro"] += k * qe
        # fusión complementaria
        diff = [(hg - r["h_baro"]) if (r["h_baro"] is not None and hg is not None) else None
                for r, hg in zip(rows, gps_h_s)]
        lp = moving_average(gps_t, diff, args.fuse_tau, 0.2)
        mode = args.vertical
        for r, l, hg in zip(rows, lp, gps_h_s):
            if r["h_baro"] is None:
                r["h_fused"] = hg
            elif mode == "baro":
                r["h_fused"] = r["h_baro"]
            elif mode == "gps":
                r["h_fused"] = hg
            else:
                r["h_fused"] = r["h_baro"] + (l if l is not None else 0.0)
        resid = [d - l for d, l in zip(diff, lp) if d is not None and l is not None]
        report["baro"]["gps_minus_baro_after_lp_rms_m"] = fmt(rms(resid))
        report["baro"]["fusion"] = f"{mode} tau={args.fuse_tau}s"
    else:
        for r, hg in zip(rows, gps_h_s):
            r["h_baro"] = None
            r["dyn_flag"] = 0
            r["h_fused"] = hg
    for r in rows:
        r["h_rel"] = r["h_fused"] - ref["h"] if r["h_fused"] is not None else None
        r["h_abs"] = r["h_fused"] if ref["absolute"] else None
        r["h_gps_raw"] = frame.h0 + r["u_raw"]
        r["h_gps_corr"] = frame.h0 + r["u_gps"]

    # ---------------- vueltas + perfil
    gate = None
    if args.gate:
        p = [float(x) for x in args.gate.split(",")]
        ge, gn, _ = frame.enu(p[0], p[1], 0)
        gate = (ge, gn, p[2] if len(p) > 2 else 12.0)
    else:
        gate = auto_gate(rows, args)
    laps = split_laps(rows, gate, args)
    for r in rows:
        r["lap"] = ""
    for k, (a, b) in enumerate(laps, 1):
        for i in range(a, b):
            rows[i]["lap"] = k
    if gate:
        glat, glon, _ = frame.llh(gate[0], gate[1], 0)
        report["gate"] = {"lat": glat, "lon": glon, "radius_m": gate[2], "auto": not args.gate}
    lap_stats = []
    profiles = []
    for k, (a, b) in enumerate(laps, 1):
        seg = rows[a:b + 1]
        d0 = seg[0]["dist"]
        L = seg[-1]["dist"] - d0
        ds = [r["dist"] - d0 for r in seg]
        hs = [r["h_rel"] for r in seg]
        hs_s = moving_average(ds, hs, args.profile_smooth_m) if args.profile_smooth_m > 0 else hs
        up, down = climb_descent(hs_s, args.climb_hyst)
        hv = [h for h in hs if h is not None]
        lap_stats.append({"lap": k, "length_m": round(L, 1), "t0": round(seg[0]["t"], 1),
                          "dur_s": round(seg[-1]["t"] - seg[0]["t"], 1),
                          "h_min": fmt(min(hv) if hv else None, 2), "h_max": fmt(max(hv) if hv else None, 2),
                          "climb_m": round(up, 2), "descent_m": round(down, 2)})
        profiles.append((L, ds, hs))
    report["laps"] = lap_stats
    prof_rows = []
    if profiles:
        Lm = statistics.median(p[0] for p in profiles)
        step = args.profile_step
        nstep = int(Lm / step) + 1
        for i in range(nstep):
            dgrid = i * step
            vals = []
            for L, ds, hs in profiles:
                dd = dgrid / Lm * L
                vals.append(interp(ds, hs, dd))
            ok = [v for v in vals if v is not None]
            mean = sum(ok) / len(ok) if ok else None
            sd = statistics.pstdev(ok) if len(ok) > 1 else None
            prof_rows.append((dgrid, vals, mean, sd, len(ok)))
        means = [p[2] for p in prof_rows]
        dgr = [p[0] for p in prof_rows]
        means_s = moving_average(dgr, means, args.profile_smooth_m) if args.profile_smooth_m > 0 else means
        up, down = climb_descent(means_s, args.climb_hyst)
        mv = [m for m in means if m is not None]
        report["profile_mean"] = {"length_m": round(Lm, 1), "step_m": step, "laps": len(profiles),
                                  "h_min": fmt(min(mv), 2), "h_max": fmt(max(mv), 2),
                                  "climb_m": round(up, 2), "descent_m": round(down, 2),
                                  "lap_spread_rms_m": fmt(rms([p[3] for p in prof_rows]), 2)}
    else:
        report["warnings"].append("no se detectaron vueltas (usa --gate lat,lon[,radio])")
        hs = [r["h_rel"] for r in rows]
        up, down = climb_descent(hs, args.climb_hyst)
        hv = [h for h in hs if h is not None]
        report["profile_session"] = {"h_min": fmt(min(hv) if hv else None, 2),
                                     "h_max": fmt(max(hv) if hv else None, 2),
                                     "climb_m": round(up, 2), "descent_m": round(down, 2)}
    report["vertical_note"] = ("h_rel = altura respecto a la marca REF (m). h_abs solo si REF es "
                               "coordenada medida (no 'avg'). Baro en la moto: viento/presión "
                               "dinámica a velocidad -> dyn_flag=1; usa --dyn-coef auto para "
                               "estimar y compensar.")
    write_outputs(args.out, rows, ref, report, laps, prof_rows, frame)
    return report


# ----------------------------------------------------------------- salidas
def iso(r):
    if r["utc"] is None:
        return None
    return r["utc"].strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def write_outputs(out, rows, ref, report, laps, prof_rows, frame):
    os.makedirs(out, exist_ok=True)
    cols = ["t_gps", "utc", "lat_raw", "lon_raw", "lat", "lon", "e_raw", "n_raw", "e", "n",
            "h_gps_raw", "h_gps_corr", "h_baro", "h_fused", "h_rel", "h_abs", "speed_mps", "hacc",
            "vacc", "sv", "common_sv", "overlap", "mode", "flag", "dyn_flag", "lap", "dist_m"]
    with open(os.path.join(out, "corrected.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            w.writerow([f"{r['t']:.3f}", iso(r) or "", f"{r['lat_raw']:.8f}", f"{r['lon_raw']:.8f}",
                        f"{r['lat']:.8f}", f"{r['lon']:.8f}", fmt(r["e_raw"]), fmt(r["n_raw"]),
                        fmt(r["e"]), fmt(r["n"]), fmt(r["h_gps_raw"]), fmt(r["h_gps_corr"]),
                        fmt(r["h_baro"]), fmt(r["h_fused"]), fmt(r["h_rel"]), fmt(r["h_abs"]),
                        fmt(r["speed"], 2), fmt(r["hacc"], 2), fmt(r["vacc"], 2), r["sv"],
                        "" if r["common"] is None else r["common"], fmt(r["overlap"], 2), r["mode"],
                        r["flag"], r["dyn_flag"], r["lap"], fmt(r["dist"], 1)])
    # GPX
    ele_key = "h_abs" if ref["absolute"] else "h_rel"
    with open(os.path.join(out, "corrected.gpx"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<gpx version="1.1" creator="RiderLab anchor_correct.py" '
                'xmlns="http://www.topografix.com/GPX/1/1">\n')
        f.write(f"<metadata><desc>{escape('ele=' + ele_key + ' (h_rel: metros sobre la marca REF ' + str(ref['id']) + ')')}</desc></metadata>\n")
        f.write(f'<wpt lat="{ref["lat"]:.8f}" lon="{ref["lon"]:.8f}"><ele>{ref["h"]:.3f}</ele>'
                f'<name>{escape("REF " + str(ref["id"]))}</name></wpt>\n')
        f.write("<trk><name>RiderLab corregido</name>\n")
        groups = [(k, rows[a:b + 1]) for k, (a, b) in enumerate(laps, 1)] or [(0, rows)]
        for k, seg in groups:
            f.write(f"<trkseg><!-- lap {k} -->\n" if k else "<trkseg>\n")
            for r in seg:
                ele = r[ele_key]
                t = iso(r)
                f.write(f'<trkpt lat="{r["lat"]:.8f}" lon="{r["lon"]:.8f}">'
                        + (f"<ele>{ele:.3f}</ele>" if ele is not None else "")
                        + (f"<time>{t}</time>" if t else "") + "</trkpt>\n")
            f.write("</trkseg>\n")
        f.write("</trk>\n</gpx>\n")
    # GeoJSON
    feats = []

    def line(sel, key_ele, props):
        coords = []
        for r in sel:
            c = [round(r["lon"], 8), round(r["lat"], 8)]
            if key_ele and r[key_ele] is not None:
                c.append(round(r[key_ele], 3))
            coords.append(c)
        return {"type": "Feature", "geometry": {"type": "LineString", "coordinates": coords},
                "properties": props}
    feats.append(line(rows, ele_key, {"name": "corregido", "ele": ele_key,
                                      "modes": report["correction"]["modes"]}))
    feats.append({"type": "Feature", "geometry": {"type": "LineString", "coordinates": [
        [round(r["lon_raw"], 8), round(r["lat_raw"], 8)] for r in rows]},
        "properties": {"name": "crudo"}})
    for k, (a, b) in enumerate(laps, 1):
        feats.append(line(rows[a:b + 1], ele_key, {"name": f"vuelta {k}", "lap": k,
                                                   **report["laps"][k - 1]}))
    feats.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [
        round(ref["lon"], 9), round(ref["lat"], 9), round(ref["h"], 3)]},
        "properties": {"name": "REF", **report["ref"]}})
    if report.get("gate"):
        g = report["gate"]
        feats.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [
            round(g["lon"], 8), round(g["lat"], 8)]}, "properties": {"name": "meta (gate)", **g}})
    with open(os.path.join(out, "corrected.geojson"), "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": feats}, f)
    # perfil
    with open(os.path.join(out, "profile.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        nl = len(laps)
        w.writerow(["dist_m"] + [f"lap_{k}" for k in range(1, nl + 1)] + ["mean", "std", "n"])
        for d, vals, mean, sd, n in prof_rows:
            w.writerow([f"{d:.1f}"] + [fmt(v, 3) for v in vals] + [fmt(mean, 3), fmt(sd, 3), n])
    rep = {k: v for k, v in report.items() if not k.startswith("_")}
    with open(os.path.join(out, "report.json"), "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=2, ensure_ascii=False, default=str)
    with open(os.path.join(out, "report.md"), "w", encoding="utf-8") as f:
        f.write(render_md(rep))


def render_md(r):
    L = ["# RiderLab — corrección con ancla", ""]
    ref = r["ref"]
    L.append(f"- REF `{ref['id']}` ({ref['source']}, h {ref['htype']}) lat {ref['lat']:.8f} "
             f"lon {ref['lon']:.8f} h {ref['h']:.3f} m, ANT_H {ref['ant_h']} m, "
             f"absoluta: {'sí' if ref['absolute'] else 'no (origen local)'}")
    re_ = r["rider_epochs"]
    L.append(f"- Moto: {re_['kept']}/{re_['total']} épocas válidas (hAcc<= {re_['max_hacc']} m, "
             f"sat>= {re_['min_sv']})")
    c = r["correction"]
    L.append(f"- Modos: {c['modes']}; épocas con pocos satélites comunes: {c['poor_overlap_epochs']}")
    if r.get("anchor"):
        a = r["anchor"]
        L.append(f"- Ancla: {a['epochs_used']} épocas, suavizado {a['smooth_s']} s, error RMS "
                 f"E {a['err_rms_m']['e']} N {a['err_rms_m']['n']} U {a['err_rms_m']['u']} m")
    L += ["", "## Validación en estáticos sobre el punto", "",
          "| tramo | n | RMS horiz crudo | RMS horiz corr | RMS vert crudo | RMS vert corr | in-sample |",
          "|---|---|---|---|---|---|---|"]
    for v in r["static_validation"]:
        L.append(f"| {v['t0']}–{v['t1']} ({v['src']}) | {v['n']} | {v['rms_h_raw_m']} | "
                 f"{v['rms_h_corr_m']} | {v['rms_u_raw_m']} | {v['rms_u_corr_m']} | {v['in_sample']} |")
    if not r["static_validation"]:
        L.append("| (sin estáticos sobre el punto) | | | | | | |")
    b = r.get("baro", {})
    L += ["", "## Altura", "", f"- Baro: {b.get('mode')}  T aire {b.get('air_temp_c')} °C "
          f"({b.get('air_temp_src')}); co-location {b.get('coloc')}; k dinámico ajustado "
          f"{b.get('dyn_k_fit')} aplicado {b.get('dyn_k_applied')}; fusión {b.get('fusion')}"]
    if b.get("warning"):
        L.append(f"- ⚠ {b['warning']}")
    if r.get("profile_mean"):
        p = r["profile_mean"]
        L.append(f"- Perfil promedio ({p['laps']} vueltas, {p['length_m']} m): h {p['h_min']}…"
                 f"{p['h_max']} m, ascenso {p['climb_m']} m, descenso {p['descent_m']} m, "
                 f"dispersión entre vueltas RMS {p['lap_spread_rms_m']} m")
    L += ["", "| vuelta | largo m | h min | h max | ascenso | descenso |", "|---|---|---|---|---|---|"]
    for lp in r.get("laps", []):
        L.append(f"| {lp['lap']} | {lp['length_m']} | {lp['h_min']} | {lp['h_max']} | "
                 f"{lp['climb_m']} | {lp['descent_m']} |")
    if r["warnings"]:
        L += ["", "## Avisos", ""] + [f"- {w}" for w in r["warnings"]]
    L += ["", r["static_validation_note"], "", r["vertical_note"], ""]
    return "\n".join(L)


def build_parser():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--rider", required=True, help="carpeta de sesión de la moto")
    p.add_argument("--anchor", help="carpeta de sesión del ancla (opcional: sin ella, solo deriva)")
    p.add_argument("--out", required=True, help="carpeta de salida")
    p.add_argument("--ref", help="lat,lon,h[,ell|msl] de la MARCA (anula el REF del ancla)")
    p.add_argument("--ant-h", type=float, help="altura antena ancla sobre la marca (m)")
    p.add_argument("--rider-ant-h", type=float, default=0.0, help="altura antena moto (m, vertical)")
    p.add_argument("--smooth-s", type=float, default=30.0, help="suavizado del error del ancla (s)")
    p.add_argument("--max-hacc", type=float, default=3.0)
    p.add_argument("--min-sv", type=int, default=6)
    p.add_argument("--min-overlap", type=float, default=0.7, help="fracción mínima de sat comunes")
    p.add_argument("--min-common", type=int, default=6)
    p.add_argument("--poor-overlap", choices=["flag", "fallback"], default="flag")
    p.add_argument("--mode", choices=["auto", "anchor", "drift", "none"], default="auto")
    p.add_argument("--static-speed", type=float, default=0.5)
    p.add_argument("--static-min-s", type=float, default=20.0)
    p.add_argument("--coloc-radius", type=float, default=8.0)
    p.add_argument("--gate", help="lat,lon[,radio_m] de la línea de meta (auto si falta)")
    p.add_argument("--min-lap-m", type=float, default=300.0)
    p.add_argument("--profile-step", type=float, default=1.0)
    p.add_argument("--climb-hyst", type=float, default=0.5, help="histéresis ascenso/descenso (m)")
    p.add_argument("--profile-smooth-m", type=float, default=5.0,
                   help="suavizado a lo largo del recorrido para estadísticas de ascenso (m)")
    p.add_argument("--vertical", choices=["fused", "baro", "gps"], default="fused")
    p.add_argument("--fuse-tau", type=float, default=120.0)
    p.add_argument("--air-temp-c", type=float, help="temperatura del aire (°C) para la escala")
    p.add_argument("--dyn-coef", default="0", help="0 | auto | k (presión dinámica)")
    p.add_argument("--baro-max-speed", type=float, default=10.0, help="m/s para dyn_flag")
    p.add_argument("--baro-lp-s", type=float, default=0.0, help="pasa-bajos extra baro moto (s)")
    p.add_argument("--anchor-baro-smooth-s", type=float, default=5.0)
    p.add_argument("--anchor-baro-h", type=float, help="altura del sensor del ancla sobre la marca")
    p.add_argument("--baro-offset-pa", type=float, help="offset moto-ancla fijo (si no hubo co-location)")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    rep = process(args)
    print(render_md({k: v for k, v in rep.items() if not k.startswith("_")}))
    print(f"\nSalida: {os.path.abspath(args.out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
