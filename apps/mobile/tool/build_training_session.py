"""Build a bundled OFF-mode training session from the 9 Oct 2026 survey.

Reads suave/analisis + sector times and writes
assets/offroad/sessions/2026-10-09_8horas.json for the lujumicroservices account.
"""

import csv
import json
import pathlib

EXPORT = pathlib.Path(r"C:\Users\jvald\code\riderlab-rides-export\export-20261009")
OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "offroad" / "sessions" / "2026-10-09_8horas.json"

analisis = json.loads((EXPORT / "suave/analisis/analisis_suave.json").read_text(encoding="utf-8"))
times = list(csv.DictReader((EXPORT / "suave/tiempos/comparacion_sectores_crudo_vs_suave.csv").open(encoding="utf-8")))

PILOT = ["a169", "b029", "a7e7"]
SESSION_IDS = {
    "a169": "3876d0c9-a169-1a06-c92d-d0c92df4a9a2",
    "b029": "3876d0c9-b029-28d6-c92d-d0c92df47466",
    "a7e7": "3876d0c9-a7e7-38bf-c92d-d0c92df48714",
}


def brakes(key):
    p = EXPORT / f"suave/analisis/{key}_frenadas_suave.csv"
    if not p.exists():
        return []
    return list(csv.DictReader(p.open(encoding="utf-8")))


passes = []
for key in PILOT:
    s = analisis["stats"][key]
    sectors = []
    for row in times:
        if row["ride"] != key:
            continue
        sectors.append({
            "name": row["sector"].replace("*partial", ""),
            "partial": "*partial" in row["sector"],
            "time_s": float(row["t_suave_s"]),
            "note": row.get("nota") or None,
        })
    bz = brakes(key)
    passes.append({
        "id": key,
        "session_id": SESSION_IDS[key],
        "start_local": s["start"],
        "end_local": s["end"],
        "duration_s": s["duration_s"],
        "moving_s": s["moving_s"],
        "distance_m": s["distance_m"],
        "vmax_kmh": s["vmax_kmh"],
        "vavg_kmh": s["vavg_moving_kmh"],
        "lean_max_r": s["lean_max_right_deg_est"],
        "lean_max_l": abs(s["lean_max_left_deg_est"]),
        "brake_peak_g": s["brake_peak_g"],
        "accel_peak_g": s["accel_peak_g"],
        "braking_zones": s["braking_zones"],
        "pct_outside": s["pct_outside_corridor_suave"],
        "outside_max_m": s["outside_by_max_m"],
        "median_dist_outer_m": s["median_dist_outer_m"],
        "median_dist_inner_m": s["median_dist_inner_m"],
        "maxlean_sector": s["maxlean_sector"],
        "hardest_brake_sector": s["hardest_brake_sector"],
        "braking_zones_per_sector": s["braking_zones_per_sector"],
        "sectors": sectors,
        "brakes": [{
            "sector": b["sector"],
            "lap_m": float(b["lap_distance_m"]),
            "v_in": float(b["v_in_kmh"]),
            "v_out": float(b["v_out_kmh"]),
            "peak_g": float(b["peak_decel_g"]),
            "duration_s": float(b["duration_s"]),
        } for b in bz],
    })

best_s2 = min((p for p in passes if any(s["name"] == "S2" and not s["partial"] for s in p["sectors"])),
              key=lambda p: next(s["time_s"] for s in p["sectors"] if s["name"] == "S2"))
best_s3 = min((p for p in passes if any(s["name"] == "S3" and not s.get("note") for s in p["sectors"]
                                         if s["name"] == "S3" and "stopped" not in (s.get("note") or ""))),
              key=lambda p: next(s["time_s"] for s in p["sectors"] if s["name"] == "S3"
                                 and "stopped" not in (s.get("note") or "")))
# a7e7 S3 has stop note — exclude from best S3 already via note filter above; a169 wins S3
fastest = min(passes, key=lambda p: p["duration_s"])
cleanest = min(passes, key=lambda p: p["pct_outside"])
t_s2 = next(s["time_s"] for s in best_s2["sectors"] if s["name"] == "S2")
t_s3 = next(s["time_s"] for s in best_s3["sectors"] if s["name"] == "S3")

insights = [
    {
        "kind": "good",
        "title": "Línea limpia",
        "body": f"La pasada {cleanest['id']} se quedó dentro del corredor el "
                f"{100 - cleanest['pct_outside']:.1f} % del tiempo "
                f"(máx. fuera {cleanest['outside_max_m']:.1f} m). El mapeo de 6.8 m de ancho medio "
                "aguanta la rodada a ~23 km/h.",
        "pass_id": cleanest["id"],
        "sector": None,
    },
    {
        "kind": "good",
        "title": "Mejor S2",
        "body": f"{best_s2['id']} hizo S2 en {t_s2:.2f} s — el mejor sector del día. "
                f"Inclinación punta en {best_s2['maxlean_sector']} "
                f"({max(best_s2['lean_max_l'], best_s2['lean_max_r']):.0f}° estimada).",
        "pass_id": best_s2["id"],
        "sector": "S2",
    },
    {
        "kind": "good",
        "title": "Mejor S3",
        "body": f"{best_s3['id']} cerró S3 en {t_s3:.2f} s sin parar. "
                f"Vuelta teórica parcial S2+S3 = {t_s2 + t_s3:.2f} s.",
        "pass_id": best_s3["id"],
        "sector": "S3",
    },
    {
        "kind": "good",
        "title": "Ritmo más alto",
        "body": f"{fastest['id']} fue la pasada más rápida del día "
                f"({fastest['duration_s']/60:.1f} min, {fastest['vmax_kmh']:.0f} km/h punta, "
                f"{fastest['vavg_kmh']:.0f} km/h media).",
        "pass_id": fastest["id"],
        "sector": None,
    },
    {
        "kind": "bad",
        "title": "Sin vuelta lanzada",
        "body": "Las tres pasadas arrancaron paradas a mitad de S1. Ninguna cruzó la meta "
                "lanzada, así que no hay tiempo de vuelta completo ni S1 válido. "
                "Próxima sesión: cruzar S/F ya en marcha.",
        "pass_id": None,
        "sector": "S1",
    },
    {
        "kind": "bad",
        "title": "Parada en S3 (a7e7)",
        "body": "a7e7 se detuvo más de 3 s dentro de S3 (133.6 s). Ese sector no cuenta "
                "para el mejor. Revisar ritmo en la zona de 1180–1300 m de arco.",
        "pass_id": "a7e7",
        "sector": "S3",
    },
    {
        "kind": "bad",
        "title": "Salidas del corredor",
        "body": "Aunque el % fuera es bajo, las tres pasadas rozaron 1.2–1.6 m fuera del "
                "borde suave. Con el M9N eso puede ser ruido, pero en bermas conviene "
                "revisar el mapa por pasada.",
        "pass_id": None,
        "sector": None,
    },
    {
        "kind": "bad",
        "title": "Frenada dura al final de S3",
        "body": f"a169 frenó 0.31 g a 1370 m (meta) bajando de 35 a 24 km/h. "
                f"b029 hizo 0.35 g justo después de S/F. "
                "Apunta a llegada tarde a la siguiente curva: soltar antes o alinear antes.",
        "pass_id": "a169",
        "sector": "S3",
    },
]

session = {
    "schema": "riderlab.offroad.session.v1",
    "id": "2026-10-09_8horas",
    "owner": "lujumicroservices",
    "circuit_id": "8horas",
    "circuit_name": "8 Horas Raceway",
    "date": "2026-10-09",
    "title": "Entrenamiento 8 Horas — 9 oct 2026",
    "subtitle": "3 pasadas de piloto sobre el circuito mapeado el mismo día",
    "summary": {
        "passes": len(passes),
        "distance_km": round(sum(p["distance_m"] for p in passes) / 1000, 2),
        "best_duration_s": fastest["duration_s"],
        "vmax_kmh": max(p["vmax_kmh"] for p in passes),
        "best_outside_pct": cleanest["pct_outside"],
        "best_s2_s": t_s2,
        "best_s3_s": t_s3,
        "theoretical_partial_s": round(t_s2 + t_s3, 2),
        "flying_laps": 0,
    },
    "mapping": {
        "date": "2026-10-09",
        "outer_logger": "3876",
        "inner_logger": "a057",
        "length_m": 1370.3,
        "width_median_m": 6.8,
        "geometry": "embedded-20261009-suave",
    },
    "passes": passes,
    "insights": insights,
}

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(session, ensure_ascii=False, indent=2), encoding="utf-8")
print("wrote", OUT, "passes", len(passes), "insights", len(insights))
print("best S2", best_s2["id"], t_s2, "best S3", best_s3["id"], t_s3)
