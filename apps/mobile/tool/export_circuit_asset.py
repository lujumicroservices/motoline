"""Convert a Métrica firmware circuit (RLC1 header + elevation header) into an app asset.

Usage:
  python export_circuit_asset.py <CircuitEmbedded_suave.h> <CircuitElevation.h> <out.json>
      [--id 8horas] [--name "8 Horas Raceway"] [--mapped 2026-10-09]

The RLC1 layout is documented in the firmware's CircuitFile.h. Points are int16 ENU
offsets from the anchor (first fix of the outer mapping pass = start/finish).
"""

import json
import math
import re
import struct
import sys
import zlib

args = [a for a in sys.argv[1:] if not a.startswith("--")]
RLC_H, ELEV_H, OUT = args[:3]


def opt(flag, default):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def c_array(text, name):
    m = re.search(name + r"\[[^\]]*\]\s*=\s*\{(.*?)\};", text, re.S)
    if not m:
        raise SystemExit("array not found: " + name)
    return [int(v, 0) for v in re.findall(r"-?0x[0-9a-fA-F]+|-?\d+", m.group(1))]


def c_const(text, name):
    m = re.search(name + r"\s*=\s*([-\d.]+)", text)
    return float(m.group(1)) if m else None


def parse_rlc(b):
    if b[:4] != b"RLC1":
        raise SystemExit("not RLC1")
    if zlib.crc32(b[:-4]) & 0xFFFFFFFF != struct.unpack_from("<I", b, len(b) - 4)[0]:
        raise SystemExit("bad crc")
    ccw = bool(b[5] & 1)
    unit = struct.unpack_from("<H", b, 6)[0] / 1000.0
    lat0, lon0 = struct.unpack_from("<dd", b, 8)
    alt0, len_m, head0 = struct.unpack_from("<fff", b, 24)
    n_o, n_i, n_c = struct.unpack_from("<HHH", b, 36)
    n_g, n_s = b[42], b[43]
    name = b[44:68].split(b"\0")[0].decode("utf-8")
    r = math.radians(lat0)
    ky = 111132.92 - 559.82 * math.cos(2 * r) + 1.175 * math.cos(4 * r)
    kx = 111412.84 * math.cos(r) - 93.5 * math.cos(3 * r)

    p = 68

    def pts(n):
        nonlocal p
        out = []
        for _ in range(n):
            x, y = struct.unpack_from("<hh", b, p)
            p += 4
            out.append((x * unit, y * unit))
        return out

    outer, inner, center = pts(n_o), pts(n_i), pts(n_c)
    gates = []
    for _ in range(n_g):
        ax, ay, bx, by, s_dm = struct.unpack_from("<hhhhH", b, p)
        kind = b[p + 10]
        p += 11
        gates.append({"a": (ax * unit, ay * unit), "b": (bx * unit, by * unit),
                      "s": s_dm / 10.0, "kind": kind})

    def ll(xy):
        return [round(lat0 + xy[1] / ky, 8), round(lon0 + xy[0] / kx, 8)]

    return {
        "raw_name": name, "ccw": ccw, "lat0": lat0, "lon0": lon0, "alt0": alt0,
        "len_m": len_m, "head0": head0, "n_sectors": n_s,
        "outer_xy": outer, "inner_xy": inner, "center_xy": center, "gates_raw": gates,
        "outer": [ll(q) for q in outer], "inner": [ll(q) for q in inner],
        "center": [ll(q) for q in center],
        "gates": [{"a": ll(g["a"]), "b": ll(g["b"]), "s": round(g["s"], 1), "kind": g["kind"]}
                  for g in gates],
    }


def nearest_dist(p, poly):
    best = float("inf")
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dy * dy or 1e-9
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
        best = min(best, math.hypot(a[0] + t * dx - p[0], a[1] + t * dy - p[1]))
    return best


def cum_lengths(poly):
    out = [0.0]
    for a, b in zip(poly, poly[1:]):
        out.append(out[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    return out


def main():
    rlc_text = open(RLC_H, encoding="utf-8").read()
    elev_text = open(ELEV_H, encoding="utf-8").read()
    c = parse_rlc(bytes(v & 0xFF for v in c_array(rlc_text, "kEmbeddedCircuit")))

    elev_dm = c_array(elev_text, "kElevDm")
    step = c_const(elev_text, "kElevStepM")
    base = c_const(elev_text, "kElevBaseM")
    src = re.search(r'kElevSrc\s*=\s*"([^"]+)"', elev_text).group(1)

    # Width sampled along the centerline: distance to each edge, summed.
    cum = cum_lengths(c["center_xy"] + [c["center_xy"][0]])
    widths = [nearest_dist(q, c["outer_xy"]) + nearest_dist(q, c["inner_xy"]) for q in c["center_xy"]]

    bounds = sorted(g["s"] for g in c["gates_raw"] if g["kind"] <= 1)
    if not bounds or bounds[0] > 1:
        bounds = [0.0] + bounds
    bounds.append(c["len_m"])
    sectors = []
    for k in range(len(bounds) - 1):
        s0, s1 = bounds[k], bounds[k + 1]
        if s1 - s0 < 1:
            continue
        ws = [w for w, s in zip(widths, cum) if s0 <= s < s1] or widths
        es = [base + elev_dm[i] / 10 for i in range(len(elev_dm)) if s0 <= i * step <= s1]
        sectors.append({
            "name": "S%d" % (len(sectors) + 1),
            "start_m": round(s0, 1), "end_m": round(s1, 1), "length_m": round(s1 - s0, 1),
            "width_min": round(min(ws), 1), "width_max": round(max(ws), 1),
            "width_median": round(sorted(ws)[len(ws) // 2], 1),
            "elev_min": round(min(es), 1) if es else None, "elev_max": round(max(es), 1) if es else None,
        })

    elev = [round(base + v / 10, 1) for v in elev_dm]
    asset = {
        "schema": "riderlab.circuit.v1",
        "id": opt("--id", "8horas"),
        "name": opt("--name", "8 Horas Raceway"),
        "place": opt("--place", "Av. Las Torres, Paraísos del Colli, Zapopan"),
        "mapped_on": opt("--mapped", "2026-10-09"),
        "source": c["raw_name"],
        "direction": "CCW" if c["ccw"] else "CW",
        "anchor": {"lat": c["lat0"], "lon": c["lon0"], "alt": round(c["alt0"], 1)},
        "start_heading_deg": round(c["head0"], 1),
        "length_m": round(c["len_m"], 1),
        "width": {"min": round(min(widths), 1), "max": round(max(widths), 1),
                  "median": round(sorted(widths)[len(widths) // 2], 1)},
        "outer": c["outer"], "inner": c["inner"], "center": c["center"],
        "gates": c["gates"],
        "sectors": sectors,
        "elevation": {"source": src, "step_m": step, "base_m": base, "values_m": elev,
                      "min_m": min(elev), "max_m": max(elev)},
        "mapping": {
            "loggers": [{"id": "3876", "edge": "outer"}, {"id": "a057", "edge": "inner"}],
            "receiver": "u-blox NEO-M9N 10 Hz, GPS+GLO+GAL+BDS",
            "smoothing": {"outlier_m": 6.0, "resample_m": 0.5, "method": "Gauss periódico + twicing",
                          "max_dev_outer_m": 0.92, "max_dev_inner_m": 0.90,
                          "rms_outer_m": 0.08, "rms_inner_m": 0.12,
                          "self_intersections": 0, "inner_inside_outer_pct": 100},
        },
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(asset, f, ensure_ascii=False, separators=(",", ":"))
    print(json.dumps({k: asset[k] for k in ("name", "direction", "length_m", "width", "sectors")},
                     ensure_ascii=False, indent=1))
    print("points outer/inner/center:", len(c["outer"]), len(c["inner"]), len(c["center"]),
          "gates:", len(c["gates"]), "elev:", len(elev), "->", OUT)


if __name__ == "__main__":
    main()
