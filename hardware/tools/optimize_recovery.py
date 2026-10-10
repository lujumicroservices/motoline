"""Recovery rally: night transfer to a far hotel, Sunday harvest until 11:30.

The rider already marked Saturday checkpoints through Zacoalco. Tonight they
pick up a bike at Periferico & Santa Margarita, ride to Tapalpa (or Guzman if
that night transfer would miss midnight), sleep, then from 06:00 collect as
many remaining south-west checkpoints as fit before the depot at 11:30.
"""

from __future__ import annotations

import csv
import json
import sys
import time
import unicodedata

import optimize_route as opt

OUT = opt.OUT_DIR / "ruta_off_1_recuperacion.json"
EXCEL = opt.OUT_DIR / "Checkpoints_Rally_2026.csv"

PICKUP = {
    "name": "Periferico y Santa Margarita",
    "desc": "Recoge la moto en Zapopan",
    "lat": 20.721,
    "lng": -103.405,
    "terrain": "pavement",
    "points": 0,
    "order": 0,
}
TAPALPA = {"name": "Tapalpa", "lat": 19.945131, "lng": -103.757891}
GUZMAN_HOTEL = {
    "id": "manual/molino",
    "name": "El Molino del Rey",
    "desc": "Hotel de respaldo en Zapotiltic",
    "lat": 19.5569356,
    "lng": -103.378714,
    "terrain": "pavement",
    "points": 0,
    "order": 0,
    "away_km": 0.0,
}
FALLBACK_TAPALPA_HOTEL = {
    "id": "manual/tapalpa",
    "name": "Hotel en Tapalpa (pueblo)",
    "desc": "Pernocta en el pueblo; elige el hotel al llegar",
    "lat": TAPALPA["lat"],
    "lng": TAPALPA["lng"],
    "terrain": "pavement",
    "points": 0,
    "order": 0,
    "away_km": 0.0,
}

# Already scored on Saturday through Zacoalco (original plan CP 1-25).
VISITED = {
    "mi ranchito",
    "torres del maizal",
    "el arbolon",
    "los volcanes",
    "shalo",
    "pemex",
    "la y",
    "la quebradita",
    "el barro",
    "los mogotes",
    "el jaral",
    "los agaves",
    "hidalgo",
    "villa corona",
    "laguna de atotonilco",
    "el tepal",
    "el arbol",
    "via a acatlan",
    "los maizales",
    "acatlan de juarez",
    "san jose de los pozos",
    "san marcos",
    "camino real",
    "laguna de san marcos",
    "zacoalco",
}
# Start-line ceremony CPs sit on the depot; Encore is the one we keep.
SKIP_NAMES = VISITED | {
    "kit de bienvenida",
    "ultimo reto",
    "banderazo de salida",
    "foto en grupo",
}

# Original remaining CPs after Zacoalco plus leftover valley towns on that line.
ALLOW = {
    "barranca de otates",
    "la puerta",
    "tres caminos",
    "la cima",
    "tierra blanca",
    "la bodega",
    "super cactus",
    "puerto de montana",
    "los importantes",
    "las piedrotas",
    "tapalpa",
    "bosques de la canada",
    "rancho de los ovejos",
    "torre ixtepeme",
    "cultivadero",
    "la t",
    "el divisadero",
    "ferreria de tula",
    "gran torre",
    "volcan",
    "nevado",
    "sayulapan",
    "ciudad guzman",
    "zapotlan",
    "zapotiltic",
    "vista hermosa",
    "tamazula",
    "contla",
    "manzanilla la paz",
    "encore",
    "atemajac",
    "sayula",
    "mirador de la laguna",
    "las pitayas",
    "los cactus",
    "techaluta",
    "las gaviotas",
    "los cinturones",
    "atoyac",
    "laguna de sayula",
    "cofradia del rosario",
    "tonaya",
    "chiquilistlan",
    "cerro pelon",
    "epeche grande",
    "concepcion",
    "el tulillo",
    "virgen del camino",
    "cerro viejo",
}

SUN_START = 6.0
SUN_DEADLINE = 11.5
HOTEL_LIMIT = 24.0
NIGHT_DEPART = 20.0
NIGHT_MAX_H = 3.75
MEAL_SUN_MIN = opt.MEAL_SUN_MIN
MEAL_SUN_AFTER = opt.MEAL_SUN_AFTER
CP_MIN = opt.CP_MIN
FUEL_MIN = opt.FUEL_MIN
FUEL_TARGET_KM = opt.FUEL_TARGET_KM


def norm(name):
    text = unicodedata.normalize("NFKD", name or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(text.casefold().split())


def load_candidates():
    """Remaining official CPs in the recovery corridor, minus Saturday's 1-25."""
    terrain_by_name = {}
    src = opt.OUT_DIR / "ruta_off_1_optimizada.json"
    if src.exists():
        data = json.loads(src.read_text(encoding="utf-8"))
        for e in data.get("plan", []):
            if e.get("kind") == "checkpoint":
                terrain_by_name[norm(e.get("name"))] = e.get("terrain") or ""

    stops = []
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
            key = norm(name)
            if not name or key in SKIP_NAMES or key not in ALLOW:
                continue
            pts_s = (row.get("puntos") or "0").replace("+", "").replace("pts", "").strip()
            try:
                points = int(float(pts_s))
            except ValueError:
                points = 0
            if points <= 0:
                continue
            terrain = terrain_by_name.get(key) or (
                "dirt" if lat < 20.15 and lng < -103.55 else "pavement"
            )
            stops.append(
                {
                    "name": name,
                    "desc": (row.get("EVIDENCIA") or "").strip(),
                    "lat": lat,
                    "lng": lng,
                    "order": int(row.get("no") or 0),
                    "terrain": terrain,
                    "points": points,
                }
            )
    stops.sort(key=lambda s: (-s["points"], s["name"]))
    return stops


def as_hotel(raw, desc):
    if not raw:
        return None
    return {
        "id": raw.get("id") or f"manual/{raw['name']}",
        "name": raw["name"],
        "desc": desc,
        "lat": raw["lat"],
        "lng": raw["lng"],
        "terrain": "pavement",
        "points": 0,
        "order": 0,
        "away_km": raw.get("away_km", 0.0),
    }


def pick_hotel(pickup):
    # Use the pueblo pin, not Overpass: the rider picks any hotel in town.
    tapalpa = dict(FALLBACK_TAPALPA_HOTEL)
    print("calculando traslado nocturno a Tapalpa...", flush=True)
    night_min, night_km = opt.ride(pickup, tapalpa)
    if night_min / 60.0 <= NIGHT_MAX_H:
        return tapalpa, night_min, night_km, "tapalpa"
    guzman = dict(GUZMAN_HOTEL)
    print("Tapalpa queda largo; calculando respaldo Guzman...", flush=True)
    g_min, g_km = opt.ride(pickup, guzman)
    return guzman, g_min, g_km, "guzman"


def path_time(order, mins, start_i, end_i):
    prev = start_i
    total = 0.0
    for i in order:
        total += mins[prev][i]
        prev = i
    return total + mins[prev][end_i]


def nearest_path(cp_ids, mins, start_i):
    order = []
    left = list(cp_ids)
    cur = start_i
    while left:
        nxt = min(left, key=lambda j: mins[cur][j])
        order.append(nxt)
        left.remove(nxt)
        cur = nxt
    return order


def improve_path(order, mins, start_i, end_i, deadline):
    best = order[:]
    best_t = path_time(best, mins, start_i, end_i)
    moved = True
    while moved and time.time() < deadline:
        moved = False
        for i in range(len(best) - 1):
            for j in range(i + 1, len(best)):
                cand = best[:i] + best[i : j + 1][::-1] + best[j + 1 :]
                t = path_time(cand, mins, start_i, end_i)
                if t < best_t - 1e-6:
                    best, best_t, moved = cand, t, True
        for size in (1, 2, 3):
            for i in range(0, len(best) - size + 1):
                chunk = best[i : i + size]
                rest = best[:i] + best[i + size :]
                for k in range(len(rest) + 1):
                    cand = rest[:k] + chunk + rest[k:]
                    t = path_time(cand, mins, start_i, end_i)
                    if t < best_t - 1e-6:
                        best, best_t, moved = cand, t, True
                        break
                else:
                    continue
                break
    return best, best_t


def best_path(cp_ids, mins, start_i, end_i, budget_s=20):
    if not cp_ids:
        return [], 0.0
    deadline = time.time() + budget_s
    order = nearest_path(cp_ids, mins, start_i)
    order, t = improve_path(order, mins, start_i, end_i, deadline)
    return order, t


def simulate(order, nodes, mins, kms, hotel, pickup, night_min, night_km, fast=True):
    """Night transfer (no CPs) then Sunday harvest hotel -> CPs -> depot."""
    night_depart = NIGHT_DEPART
    hotel_arrive = night_depart + night_min / 60.0
    if hotel_arrive > HOTEL_LIMIT:
        night_depart = max(18.0, HOTEL_LIMIT - night_min / 60.0 - 0.25)
        hotel_arrive = night_depart + night_min / 60.0

    plan = [
        {
            "kind": "pickup",
            "name": pickup["name"],
            "desc": pickup["desc"],
            "lat": pickup["lat"],
            "lng": pickup["lng"],
            "terrain": "pavement",
            "points": 0,
            "orig": 0,
            "leg_min": 0.0,
            "leg_km": 0.0,
            "day": 1,
            "arrive": night_depart,
        },
        {
            "kind": "hotel",
            "name": hotel["name"],
            "desc": hotel.get("desc") or "Pernocta",
            "lat": hotel["lat"],
            "lng": hotel["lng"],
            "terrain": "pavement",
            "points": 0,
            "orig": 0,
            "leg_min": round(night_min, 1),
            "leg_km": round(night_km, 1),
            "day": 1,
            "arrive": hotel_arrive,
        },
        {
            "kind": "start",
            "name": hotel["name"],
            "desc": "Salida domingo 06:00",
            "lat": hotel["lat"],
            "lng": hotel["lng"],
            "terrain": "pavement",
            "points": 0,
            "orig": 0,
            "leg_min": 0.0,
            "leg_km": 0.0,
            "day": 2,
            "arrive": SUN_START,
        },
    ]

    clock = SUN_START
    tank_km = 0.0
    meal = False
    cur = hotel
    used_fuel = set()
    depot_i = 1
    queue = list(order) + [depot_i]

    for pos, idx in enumerate(queue):
        nxt = nodes[idx]
        last = pos == len(queue) - 1
        leg_min, leg_km = opt.ride(cur, nxt)

        if tank_km + leg_km > FUEL_TARGET_KM:
            station = opt.nearest_service("fuel", cur, used_fuel, 12) if not fast else None
            if station is None:
                station, in_min, in_km = opt._fast_fuel(cur), opt.FUEL_DETOUR_MIN, opt.FUEL_DETOUR_KM
            else:
                in_min, in_km = opt.ride(cur, station)
            used_fuel.add(station["id"])
            clock += in_min / 60
            dwell = FUEL_MIN
            meal_note = ""
            if not meal and clock >= MEAL_SUN_AFTER:
                dwell += MEAL_SUN_MIN
                meal = True
                meal_note = " + refrigerio"
            plan.append(
                {
                    "kind": "fuel",
                    "name": station["name"],
                    "desc": (station.get("brand") or "Gasolinera")
                    + f" a {station.get('away_km', 0)} km de la ruta{meal_note}",
                    "lat": station["lat"],
                    "lng": station["lng"],
                    "terrain": "pavement",
                    "points": 0,
                    "orig": 0,
                    "leg_min": round(in_min, 1),
                    "leg_km": round(in_km, 1),
                    "day": 2,
                    "arrive": clock,
                    "dwell_min": dwell,
                    "tank_km": round(tank_km + in_km, 1),
                }
            )
            clock += dwell / 60
            cur, tank_km = station, 0.0
            leg_min, leg_km = opt.ride(cur, nxt)

        clock += leg_min / 60
        entry = {
            "kind": "depot" if last else "checkpoint",
            "name": nxt["name"],
            "desc": nxt.get("desc") or ("Meta 11:30" if last else ""),
            "lat": nxt["lat"],
            "lng": nxt["lng"],
            "terrain": nxt.get("terrain") or "pavement",
            "points": 0 if last else nxt["points"],
            "orig": nxt.get("order") or 0,
            "leg_min": round(leg_min, 1),
            "leg_km": round(leg_km, 1),
            "day": 2,
            "arrive": clock,
            "node": idx,
        }
        tank_km += leg_km
        if not last:
            dwell = CP_MIN
            if not meal and clock >= MEAL_SUN_AFTER:
                dwell += MEAL_SUN_MIN
                meal = True
                entry["meal"] = True
            entry["dwell_min"] = dwell
            clock += dwell / 60
        plan.append(entry)
        cur = nxt

    finish = plan[-1]["arrive"]
    info = {
        "finish": finish,
        "hotel_arrive": hotel_arrive,
        "night_depart": night_depart,
        "ok": finish <= SUN_DEADLINE and hotel_arrive <= HOTEL_LIMIT,
        "over_min": max(0.0, (finish - SUN_DEADLINE) * 60),
    }
    return plan, info


def worst_value(order, nodes, mins, hotel_i, depot_i, protected=()):
    worst, worst_ratio = None, None
    for k, i in enumerate(order):
        if i in protected:
            continue
        prev = hotel_i if k == 0 else order[k - 1]
        nxt = depot_i if k == len(order) - 1 else order[k + 1]
        saved = mins[prev][i] + mins[i][nxt] - mins[prev][nxt] + CP_MIN
        ratio = nodes[i]["points"] / max(saved, 0.5)
        if worst_ratio is None or ratio < worst_ratio:
            worst, worst_ratio = i, ratio
    return worst


def main():
    print("recuperacion: cargando candidatos...", flush=True)
    pickup = PICKUP
    depot = dict(opt.DEPOT)
    depot["desc"] = "Llegada domingo 11:30"

    hotel, night_min, night_km, hotel_kind = pick_hotel(pickup)
    latest_depart = HOTEL_LIMIT - night_min / 60.0
    print(
        f"hotel {hotel['name']} ({hotel_kind})  "
        f"noche {night_km:.1f} km / {night_min/60:.2f} h  "
        f"salir a mas tardar {opt.hhmm(latest_depart)}"
    )

    stops = load_candidates()
    nodes = [hotel, depot] + stops
    hotel_i, depot_i = 0, 1
    n = len(nodes)
    print(f"{len(stops)} CP candidatos en el corredor (sin los 25 de sabado)")

    opt.prefetch([(nodes[i], nodes[j]) for i in range(n) for j in range(i + 1, n)])
    opt.prefetch([(pickup, hotel)])
    mins = [[0.0] * n for _ in range(n)]
    kms = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            m, k = opt.ride(nodes[i], nodes[j])
            mins[i][j] = mins[j][i] = m
            kms[i][j] = kms[j][i] = k
    opt.save_times()

    def run(order, fast):
        return simulate(order, nodes, mins, kms, hotel, pickup, night_min, night_km, fast=fast)

    pinned = [
        i
        for i, node in enumerate(nodes)
        if i >= 2 and opt.haversine(hotel, node) / 1000 <= 6.0
    ]
    pinned.sort(key=lambda i: opt.haversine(hotel, nodes[i]))
    print(
        "anclados al hotel: " + ", ".join(nodes[i]["name"] for i in pinned),
        flush=True,
    )

    def shed(order, removed, fast):
        plan, info = run(order, fast)
        while not info["ok"] and any(i not in pinned for i in order):
            drop = worst_value(order, nodes, mins, hotel_i, depot_i, protected=pinned)
            if drop is None:
                break
            removed.append(drop)
            order = [i for i in order if i != drop]
            rest = [i for i in order if i not in pinned]
            rest, _ = best_path(rest, mins, (pinned[-1] if pinned else hotel_i), depot_i, 8)
            order = pinned + [i for i in rest if i not in pinned]
            plan, info = run(order, fast)
        return order, plan, info

    def reinsert(order, plan, info, removed, fast):
        for cand in sorted(removed, key=lambda i: -nodes[i]["points"]):
            options = []
            for k in range(len(order) + 1):
                trial = order[:k] + [cand] + order[k:]
                t_plan, t_info = run(trial, fast)
                if t_info["ok"]:
                    options.append((t_info["finish"], trial, t_plan, t_info))
            if options:
                _, order, plan, info = min(options, key=lambda o: o[0])
                removed.remove(cand)
        return order, plan, info

    rest_ids = [i for i in range(2, n) if i not in pinned]
    rest, _ = best_path(rest_ids, mins, (pinned[-1] if pinned else hotel_i), depot_i, 20)
    order = pinned + rest
    plan, info = run(order, True)
    print(f"con los {len(order)} CP: llegada {info['finish']:.2f} h, sobran {info['over_min']:.0f} min")

    removed = []
    order, plan, info = shed(order, removed, True)
    order, plan, info = reinsert(order, plan, info, removed, True)
    opt.save_times()

    for e in plan:
        e["arrive_hhmm"] = opt.hhmm(e["arrive"])

    days = {}
    for e in plan:
        d = days.setdefault(e["day"], {"km": 0.0, "ride": 0.0, "stop": 0.0, "pts": 0, "cp": 0})
        d["km"] += e["leg_km"]
        d["ride"] += e["leg_min"]
        d["stop"] += e.get("dwell_min", 0.0)
        d["pts"] += e["points"]
        d["cp"] += 1 if e["kind"] == "checkpoint" else 0
    day_rows = []
    for d in sorted(days):
        legs = [e for e in plan if e["day"] == d]
        day_rows.append(
            {
                "day": d,
                "label": "Noche" if d == 1 else "Domingo",
                "km": round(days[d]["km"], 1),
                "ride_h": round(days[d]["ride"] / 60, 2),
                "stop_h": round(days[d]["stop"] / 60, 2),
                "start": legs[0]["arrive_hhmm"],
                "end": legs[-1]["arrive_hhmm"],
                "end_name": legs[-1]["name"],
                "checkpoints": days[d]["cp"],
                "points": days[d]["pts"],
            }
        )

    visited = [e for e in plan if e["kind"] == "checkpoint"]
    got = sum(e["points"] for e in visited)
    avail = sum(s["points"] for s in stops)
    total_km = sum(e["leg_km"] for e in plan)
    total_ride = sum(e["leg_min"] for e in plan)
    fuel_stops = [e for e in plan if e["kind"] == "fuel"]
    slack_min = max(0.0, (SUN_DEADLINE - info["finish"]) * 60)

    stats = {
        "mode": "recovery",
        "checkpoints_visited": len(visited),
        "checkpoints_total": len(stops),
        "points": got,
        "points_available": avail,
        "points_pct": round(100 * got / max(avail, 1), 1),
        "skipped": sorted(nodes[i]["order"] for i in removed if nodes[i].get("order")),
        "skipped_names": sorted(nodes[i]["name"] for i in removed),
        "excluded_saturday": sorted(VISITED),
        "loop_km": round(total_km, 1),
        "ride_h": round(total_ride / 60, 2),
        "stop_h": round(sum(e.get("dwell_min", 0.0) for e in plan) / 60, 2),
        "avg_kmh": round(total_km / max(total_ride / 60, 0.01), 1),
        "finish": opt.hhmm(info["finish"]),
        "slack_min": round(slack_min, 0),
        "hotel": hotel["name"],
        "hotel_kind": hotel_kind,
        "hotel_arrive": opt.hhmm(info["hotel_arrive"]),
        "night_depart": opt.hhmm(info["night_depart"]),
        "latest_depart": opt.hhmm(latest_depart),
        "night_km": round(night_km, 1),
        "night_h": round(night_min / 60, 2),
        "pickup": f"{pickup['lat']}, {pickup['lng']}",
        "fuel_stops": len(fuel_stops),
        "fuel_max_km": round(max([e["tank_km"] for e in fuel_stops], default=0.0), 1),
        "dirt": sum(1 for e in visited if e["terrain"] == "dirt"),
        "pavement": sum(1 for e in visited if e["terrain"] == "pavement"),
        "depot": f"{depot['lat']}, {depot['lng']}",
        "cp_min": CP_MIN,
        "fuel_min": FUEL_MIN,
        "meal_sat_min": 0.0,
        "meal_sun_min": MEAL_SUN_MIN,
        "speed_dirt": opt.SPEED_DIRT_KMH,
        "speed_pave": opt.SPEED_PAVE_KMH,
        "speed_hwy": opt.SPEED_HWY_KMH,
        "windows": f"noche traslado | dom {opt.hhmm(SUN_START)}-{opt.hhmm(SUN_DEADLINE)}",
    }
    print(json.dumps(stats, indent=2, ensure_ascii=False))
    for r in day_rows:
        print(
            f"  {r['label']}: {r['km']:6.1f} km  {r['ride_h']:.2f} h  "
            f"{r['start']}->{r['end']}  {r['checkpoints']} CP  {r['points']} pts  fin: {r['end_name']}"
        )

    shapes = {
        "1": opt.road_shape([pickup, hotel]),
        "2": opt.road_shape(
            [hotel] + [e for e in plan if e["day"] == 2 and e["kind"] in ("checkpoint", "fuel", "depot")]
        ),
    }

    payload = {"stats": stats, "days": day_rows, "plan": plan, "shapes": shapes}
    opt.OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    print("->", OUT)
    return payload


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
