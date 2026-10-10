#!/usr/bin/env python3
"""Pruebas con datos sintéticos de anchor_correct.py (solo stdlib).

    python -m unittest tools/test_anchor_correct.py -v      (desde hardware/firmware)
"""
import csv
import datetime as dt
import json
import math
import os
import random
import shutil
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anchor_correct as ac  # noqa: E402

LAT0, LON0, H0 = 20.6659498, -103.4604636, 1720.0  # marca REF (elipsoidal)
SEP = 9.0  # msl - h
ANT_H = 1.5
RIDER_ANT = 1.0
T_AIR = 25.0
START = dt.datetime(2026, 10, 8, 18, 0, 0, tzinfo=dt.timezone.utc)
HZ = 10
PERIM_A, PERIM_B = 220.0, 120.0
CX, CY = 150.0, 100.0


def tow_ms(t):
    gps = (START - ac.GPS_EPOCH).total_seconds() + ac.LEAP_S + t
    return int(round((gps % ac.WEEK_S) * 1000))


def utc_fields(t):
    u = START + dt.timedelta(seconds=t)
    return u.strftime("%Y-%m-%dT%H:%M:%S"), int(round(u.microsecond * 1000))


def track_xy(th):
    return (CX + PERIM_A * math.cos(th) + 40 * math.cos(3 * th), CY + PERIM_B * math.sin(th))


def track_z(th):
    return 3.0 + 6.0 * math.sin(th) + 2.0 * math.sin(4 * th)


def common_err(t):
    e = 1.2 * math.sin(2 * math.pi * t / 600) + 0.4 * math.sin(2 * math.pi * t / 170 + 1)
    n = -0.9 * math.cos(2 * math.pi * t / 700) + 0.3 * math.sin(2 * math.pi * t / 130)
    u = 2.0 * math.sin(2 * math.pi * t / 900) + 0.8 * math.sin(2 * math.pi * t / 240 + 2)
    return e, n, u


def pressure(h, t):
    p0 = 101325.0 - 60.0 * (t / 1800.0)  # deriva del clima
    return p0 * math.exp(-ac.G0 * h / (ac.RD * (T_AIR + 273.15)))


class Truth:
    """Trayectoria verdadera de la moto (E,N, altura del suelo, velocidad)."""

    def __init__(self, laps=5, speed=12.0, static_s=120.0):
        self.samples = []  # (t, e, n, ground_z, v)
        dt_ = 1.0 / HZ
        t = 0.0
        # estático junto al ancla (1 m al este)
        while t < static_s:
            self.samples.append((t, 1.0, 0.0, 0.0, 0.0))
            t += dt_
        p_in = track_xy(0.0)
        L_tr = math.hypot(p_in[0] - 1.0, p_in[1])
        z_in = track_z(0.0)

        def transit(t, forward):
            d = 0.0
            while d < L_tr:
                f = d / L_tr if forward else 1 - d / L_tr
                e = 1.0 + (p_in[0] - 1.0) * f
                n = p_in[1] * f
                self.samples.append((t, e, n, z_in * f, 5.0))
                d += 5.0 * dt_
                t += dt_
            return t
        t = transit(t, True)
        # vueltas a velocidad constante
        ths = [i * 2 * math.pi / 20000 for i in range(20001)]
        pts = [track_xy(th) for th in ths]
        cum = [0.0]
        for a, b in zip(pts, pts[1:]):
            cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        self.perim = cum[-1]
        s = 0.0
        total = laps * self.perim
        import bisect
        while s < total:
            sl = s % self.perim
            i = min(bisect.bisect_left(cum, sl), len(cum) - 1)
            th = ths[i]
            x, y = pts[i]
            self.samples.append((t, x, y, track_z(th), speed))
            s += speed * dt_
            t += dt_
        t = transit(t, False)
        end = t + static_s
        while t < end:
            self.samples.append((t, 1.0, 0.0, 0.0, 0.0))
            t += dt_
        self.duration = t
        zs = [track_z(th) for th in ths]
        self.climb, self.descent = ac.climb_descent(zs, 0.5)
        self.coloc = [(5.0, static_s - 5.0), (end - static_s + 5.0, end - 5.0)]


def write_session(path, role, pvt, sats, baro, marks, manifest, aerr=None, legacy=None):
    os.makedirs(path, exist_ok=True)
    with open(os.path.join(path, "manifest.json"), "w") as f:
        f.write(json.dumps(manifest) + "\n")

    def dump(name, rows):
        with open(os.path.join(path, name), "w") as f:
            for r in rows:
                f.write(json.dumps(r) + "\n")
    if legacy is not None:
        dump("gnss.ndjson", legacy)
    else:
        dump("pvt.ndjson", pvt)
        dump("sat.ndjson", sats)
    dump("baro.ndjson", baro)
    dump("marks.ndjson", marks)
    if aerr is not None:
        dump("anchor_err.ndjson", aerr)
    # simula corte de energía: línea final truncada
    with open(os.path.join(path, "baro.ndjson"), "a") as f:
        f.write('{"t_us":1,"pa":8')


def sat_list(used_ids, extra_ids=()):
    sv = []
    for g, i in used_ids:
        sv.append([g, i, 40, 45, 120, 0x0F, 3])
    for g, i in extra_ids:
        sv.append([g, i, 25, 12, 200, 0x07, 0])
    return sv


SAT_SET = [(0, i) for i in (2, 5, 7, 9, 13, 15, 20, 24)] + [(6, i) for i in (3, 4, 10, 11)] + \
          [(2, i) for i in (1, 4, 9, 12, 19)] + [(3, i) for i in (6, 8, 14)]
ALT_SET = SAT_SET[:3] + [(3, i) for i in (20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33)]


def build_sessions(root, seed=7, dyn_k=0.0, legacy=False, poor=(400.0, 460.0)):
    rnd = random.Random(seed)
    tr = Truth()
    fr = ac.LocalFrame(LAT0, LON0, H0)
    ref = {"id": "P1", "lat": LAT0, "lon": LON0, "h": H0, "h_type": "ell", "source": "ppp",
           "sigma_m": 0.3}
    rcv = {"profile": "m9n-test", "cfg": "ok"}
    a_pvt, a_sat, a_baro, a_err, r_pvt, r_sat, r_baro, r_legacy = [], [], [], [], [], [], [], []
    rho = 0.96
    for k, (t, e, n, z, v) in enumerate(tr.samples):
        ce, cn, cu = common_err(t)
        tow = tow_ms(t)
        utc, ns = utc_fields(t)
        t_us = int(t * 1e6) + 5_000_000
        # ancla
        ae, an, au = ce + rnd.gauss(0, 0.15), cn + rnd.gauss(0, 0.15), cu + rnd.gauss(0, 0.3)
        lat, lon, h = fr.llh(ae, an, ANT_H + au)
        a_pvt.append({"t_us": t_us + 40000, "tow": tow, "utc": utc, "ns": ns, "tv": 7, "fix": 3,
                      "ok": 1, "sv": 20, "lat": round(lat, 7), "lon": round(lon, 7), "h": round(h, 3),
                      "msl": round(h + SEP, 3), "hacc": 1.2, "vacc": 2.0, "gs": 0.02, "pdop": 1.3})
        a_err.append({"tow": tow, "dist": 0})
        # moto
        re_, rn_, ru_ = e + ce + rnd.gauss(0, 0.25), n + cn + rnd.gauss(0, 0.25), cu + rnd.gauss(0, 0.5)
        lat, lon, h = fr.llh(re_, rn_, z + RIDER_ANT + ru_)
        r_pvt.append({"t_us": t_us + 120000, "tow": tow, "utc": utc, "ns": ns, "tv": 7, "fix": 3,
                      "ok": 1, "sv": 20, "lat": round(lat, 7), "lon": round(lon, 7), "h": round(h, 3),
                      "msl": round(h + SEP, 3), "hacc": 1.3, "vacc": 2.2, "gs": v, "pdop": 1.4})
        r_legacy.append({"t_us": t_us, "lat": round(lat, 7), "lng": round(lon, 7),
                         "alt": round(h + SEP, 2), "speed_mps": v, "acc_m": 1.3, "sats": 20,
                         "utc_ms": int(round(((18 * 3600) + t) * 1000)) % 86400000})
        if k % HZ == 0:
            a_sat.append({"t_us": t_us, "tow": tow, "n": len(SAT_SET), "sv": sat_list(SAT_SET)})
            use = ALT_SET if poor[0] <= t <= poor[1] else SAT_SET
            r_sat.append({"t_us": t_us, "tow": tow, "n": len(use), "sv": sat_list(use)})
        # baro 10 Hz (mismo instante)
        pa = pressure(H0 + ANT_H, t) + rnd.gauss(0, 2.0)
        a_baro.append({"t_us": t_us, "pa": round(pa, 2), "hpa": round(pa / 100, 3), "temp_c": T_AIR,
                       "tow": tow, "tsrc": "pps"})
        pr = pressure(H0 + z + RIDER_ANT, t) + 35.0 + dyn_k * 0.5 * rho * v * v + rnd.gauss(0, 2.0)
        r_baro.append({"t_us": t_us, "pa": round(pr, 2), "hpa": round(pr / 100, 3), "temp_c": 33.0,
                       "tow": tow, "tsrc": "pps"})
    r_marks = []
    for a, b in tr.coloc:
        r_marks.append({"tow": tow_ms(a), "kind": "coloc_start", "v": 0, "note": "button"})
        r_marks.append({"tow": tow_ms(b), "kind": "coloc_end", "v": 0, "note": "button"})
    anchor_dir = os.path.join(root, "anchor")
    rider_dir = os.path.join(root, "rider")
    write_session(anchor_dir, "anchor", a_pvt, a_sat, a_baro, [],
                  {"role": "anchor", "ant_h_m": ANT_H, "ref": ref, "receiver": rcv}, a_err,
                  legacy=[{"t_us": p["t_us"], "lat": p["lat"], "lng": p["lon"], "alt": p["msl"],
                           "speed_mps": 0, "acc_m": 1.2, "sats": 20,
                           "utc_ms": int(round(((18 * 3600) + i / HZ) * 1000))}
                          for i, p in enumerate(a_pvt)] if legacy else None)
    write_session(rider_dir, "rider", r_pvt, r_sat, r_baro, r_marks,
                  {"role": "rider", "receiver": rcv}, legacy=r_legacy if legacy else None)
    return tr, anchor_dir, rider_dir


def truth_rms(rows, tr, fr):
    """RMS horizontal vs verdad (t -> muestra) en vueltas, crudo y corregido."""
    idx = {round(s[0], 1): s for s in tr.samples}
    raw, cor, hz = [], [], []
    for r in rows:
        s = idx.get(round(float(r["t_rel"]), 1))
        if s is None or s[4] < 10:
            continue
        raw.append(math.hypot(float(r["e_raw"]) - s[1], float(r["n_raw"]) - s[2]))
        cor.append(math.hypot(float(r["e"]) - s[1], float(r["n"]) - s[2]))
        if r["h_rel"]:
            hz.append(float(r["h_rel"]) - s[3])
    return ac.rms(raw), ac.rms(cor), ac.rms(hz), (sum(hz) / len(hz) if hz else None)


def load_rows(out, t0):
    with open(os.path.join(out, "corrected.csv")) as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r["t_rel"] = float(r["t_gps"]) - t0
    return rows


def t0_gps():
    gps = (START - ac.GPS_EPOCH).total_seconds() + ac.LEAP_S
    week = math.floor(gps / ac.WEEK_S)
    return week * ac.WEEK_S + (gps % ac.WEEK_S)


class AnchorCorrectTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="rl_anchor_")
        cls.tr, cls.adir, cls.rdir = build_sessions(os.path.join(cls.tmp, "base"))
        cls.out = os.path.join(cls.tmp, "out")
        gate_lat, gate_lon, _ = ac.LocalFrame(LAT0, LON0, H0).llh(*track_xy(math.pi), 0)
        cls.gate = f"{gate_lat},{gate_lon},15"
        cls.rep = ac.process(ac.build_parser().parse_args(
            ["--anchor", cls.adir, "--rider", cls.rdir, "--out", cls.out, "--rider-ant-h",
             str(RIDER_ANT), "--gate", cls.gate]))
        cls.rows = load_rows(cls.out, t0_gps())

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_horizontal_correction(self):
        raw, cor, _, _ = truth_rms(self.rows, self.tr, None)
        print(f"\n  horizontal RMS en pista: crudo {raw:.3f} m -> corregido {cor:.3f} m")
        self.assertLess(cor, 0.5 * raw)
        self.assertLess(cor, 0.45)

    def test_static_validation_improves(self):
        v = self.rep["static_validation"]
        self.assertGreaterEqual(len(v), 2)
        for w in v:
            self.assertLess(float(w["rms_h_corr_m"]), float(w["rms_h_raw_m"]))

    def test_poor_overlap_flagged(self):
        segs = self.rep["correction"]["poor_overlap_segments"]
        self.assertTrue(any(s["dur_s"] >= 50 for s in segs), segs)
        flagged = [r for r in self.rows if r["flag"] == "pocos_sat_comunes"]
        ts = [r["t_rel"] for r in flagged]
        self.assertTrue(min(ts) >= 399 and max(ts) <= 461)

    def test_coloc_offset_estimated(self):
        coloc = self.rep["baro"]["coloc"]
        self.assertEqual(len(coloc), 2)
        for c in coloc:
            self.assertAlmostEqual(c["dp_pa"], 35.0, delta=3.0)

    def test_differential_baro_height(self):
        _, _, hz, bias = truth_rms(self.rows, self.tr, None)
        print(f"\n  altura fusionada vs verdad en pista: RMS {hz:.3f} m (sesgo {bias:+.3f})")
        self.assertLess(hz, 0.3)

    def test_laps_and_profile(self):
        laps = self.rep["laps"]
        self.assertEqual(len(laps), 4)  # 5 vueltas, meta a media vuelta -> 4 completas
        for lp in laps:
            self.assertAlmostEqual(lp["length_m"], self.tr.perim, delta=0.05 * self.tr.perim)
        pm = self.rep["profile_mean"]
        print(f"\n  ascenso por vuelta: {pm['climb_m']} m (verdad {self.tr.climb:.2f})")
        self.assertAlmostEqual(pm["climb_m"], self.tr.climb, delta=0.15 * self.tr.climb)
        self.assertAlmostEqual(pm["descent_m"], self.tr.descent, delta=0.15 * self.tr.descent)
        with open(os.path.join(self.out, "profile.csv")) as f:
            prof = list(csv.reader(f))
        self.assertEqual(prof[0][:2], ["dist_m", "lap_1"])
        self.assertGreater(len(prof), self.tr.perim * 0.9)

    def test_outputs_parse(self):
        root = ET.parse(os.path.join(self.out, "corrected.gpx")).getroot()
        ns = {"g": "http://www.topografix.com/GPX/1/1"}
        pts = root.findall(".//g:trkpt", ns)
        self.assertGreater(len(pts), 1000)
        self.assertIsNotNone(pts[0].find("g:ele", ns))
        self.assertIsNotNone(pts[0].find("g:time", ns))
        with open(os.path.join(self.out, "corrected.geojson")) as f:
            gj = json.load(f)
        line = gj["features"][0]["geometry"]
        self.assertEqual(line["type"], "LineString")
        self.assertEqual(len(line["coordinates"][0]), 3)  # lon, lat, ele
        self.assertTrue(os.path.exists(os.path.join(self.out, "report.md")))
        self.assertTrue(self.rep["ref"]["absolute"])

    def test_auto_gate(self):
        out = os.path.join(self.tmp, "out_auto")
        rep = ac.process(ac.build_parser().parse_args(
            ["--anchor", self.adir, "--rider", self.rdir, "--out", out,
             "--rider-ant-h", str(RIDER_ANT)]))
        self.assertGreaterEqual(len(rep["laps"]), 4)

    def test_drift_only_without_anchor(self):
        out = os.path.join(self.tmp, "out_drift")
        rep = ac.process(ac.build_parser().parse_args(
            ["--rider", self.rdir, "--out", out, "--ref", f"{LAT0},{LON0},{H0}",
             "--rider-ant-h", str(RIDER_ANT), "--gate", self.gate]))
        self.assertIn("drift", rep["correction"]["modes"])
        self.assertTrue(all(v["in_sample"] for v in rep["static_validation"]))
        self.assertIn("solo-moto", rep["baro"]["mode"])

    def test_dynamic_pressure_fit(self):
        root = os.path.join(self.tmp, "dyn")
        tr, adir, rdir = build_sessions(root, seed=11, dyn_k=0.8)
        out0 = os.path.join(root, "o0")
        out1 = os.path.join(root, "o1")
        base = ["--anchor", adir, "--rider", rdir, "--rider-ant-h", str(RIDER_ANT), "--gate",
                self.gate, "--vertical", "baro"]
        rep0 = ac.process(ac.build_parser().parse_args(base + ["--out", out0]))
        rep1 = ac.process(ac.build_parser().parse_args(base + ["--out", out1, "--dyn-coef", "auto"]))
        _, _, hz0, _ = truth_rms(load_rows(out0, t0_gps()), tr, None)
        _, _, hz1, _ = truth_rms(load_rows(out1, t0_gps()), tr, None)
        k = float(rep1["baro"]["dyn_k_fit"])
        print(f"\n  presión dinámica k=0.8: ajuste {k:.2f}; RMS altura baro {hz0:.2f} -> {hz1:.2f} m")
        self.assertAlmostEqual(k, 0.8 * 0.96, delta=0.2)
        self.assertLess(hz1, 0.5)
        self.assertGreater(hz0, 2.0)

    def test_legacy_gnss_fallback(self):
        root = os.path.join(self.tmp, "legacy")
        _, adir, rdir = build_sessions(root, seed=3, legacy=True)
        out = os.path.join(root, "o")
        rep = ac.process(ac.build_parser().parse_args(
            ["--anchor", adir, "--rider", rdir, "--out", out, "--ref", f"{LAT0},{LON0},{H0 + SEP},msl",
             "--ant-h", str(ANT_H)]))
        self.assertEqual(rep["time_base"], "sod")
        self.assertIn("anchor", rep["correction"]["modes"])

    def test_helpers(self):
        self.assertEqual(ac.climb_descent([0, 0.1, 0.2, 1.0, 0.5, 0.0, 2.0], 0.3), (3.0, 1.0))
        ts = list(range(10))
        self.assertEqual(ac.moving_average(ts, [1.0] * 10, 3)[5], 1.0)
        fr = ac.LocalFrame(LAT0, LON0, H0)
        e, n, u = fr.enu(*fr.llh(123.4, -56.7, 8.9))
        self.assertAlmostEqual(e, 123.4, places=6)
        self.assertAlmostEqual(n, -56.7, places=6)


if __name__ == "__main__":
    unittest.main(verbosity=2)
