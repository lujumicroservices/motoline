"""Plan the NorthBikers rally weekend: a closed loop from a fixed depot that
captures as many checkpoint points as possible inside hard time windows.

Rules encoded here:
  - Saturday 07:00 start at the depot; checkpoints only count until 20:00.
  - One hotel night, Sunday restart at 06:00, back at the depot by 11:00.
  - A few minutes marking each checkpoint, a meal break each day, and a refuel
    every 200-300 km.

Travel times come from Valhalla (Stadia Maps) with motorcycle costing. The
Stadia matrix/optimized endpoints need a paid plan, so the time matrix is built
from pairwise route calls cached on disk; reruns cost nothing. Fuel stations and
hotels come from OpenStreetMap via Overpass.

Usage: python optimize_route.py [route.gpx]
"""

import json
import math
import pathlib
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(
    r"C:\Users\jvald\Downloads\ruta-off-1.gpx"
)
OUT_DIR = pathlib.Path(__file__).resolve().parents[1] / "captures"
CACHE = OUT_DIR / "route_times.json"
POI_CACHE = OUT_DIR / "route_pois.json"
ENV = pathlib.Path(__file__).resolve().parents[2] / ".env.stadia"
NS = {"gpx": "http://www.topografix.com/GPX/1/1", "nb": "https://northbikers.com/gpx/1"}

# Start and finish of the rally (fixed by the organiser).
DEPOT = {
    "name": "Inicio / meta",
    "desc": "Salida sabado 07:00 y llegada domingo 11:00",
    "lat": 20.58747,
    "lng": -103.449974,
    "terrain": "pavement",
    "points": 0,
    "order": 0,
}

SAT_START = 7.0
SAT_CUTOFF = 20.0  # last hour a checkpoint still scores
SUN_START = 6.0
SUN_DEADLINE = 11.0  # must be at the finish line
HOTEL_LIMIT = 21.5  # don't plan to reach the hotel later than this

CP_MIN = 3.0  # minutes marking each checkpoint
FUEL_MIN = 12.0  # minutes per refuel
MEAL_SAT_MIN = 40.0  # comida del sabado
MEAL_SUN_MIN = 15.0  # refrigerio del domingo
MEAL_SAT_AFTER = 13.5  # take it at the first checkpoint past this hour
MEAL_SUN_AFTER = 8.5
FUEL_TARGET_KM = 250.0  # refuel window is 200-300 km
# While searching which checkpoints to keep we don't know yet which station or
# hotel we will use, so charge a slightly pessimistic detour for them.
FUEL_DETOUR_MIN, FUEL_DETOUR_KM = 10.0, 6.0
HOTEL_LEG_EST_MIN, HOTEL_LEG_EST_KM = 20.0, 15.0

COSTING = "motorcycle"
COSTING_OPTIONS = {"motorcycle": {"use_trails": 0.9, "use_highways": 0.6}}
MAX_LOCS = 50  # Valhalla limit per route request

# Distances still come from Valhalla; times use these rally speeds.
SPEED_DIRT_KMH = 60.0
SPEED_PAVE_KMH = 100.0
SPEED_HWY_KMH = 110.0
# Classify the road from Valhalla's implied speed (not its clock time).
HWY_RAW_KMH = 70.0
DIRT_RAW_KMH = 55.0

_lock = threading.Lock()


def load_key():
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith("VALHALLA_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("no VALHALLA_API_KEY in .env.stadia")


KEY = load_key()


def post_json(url, data, headers, tries=4):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            if exc.code in (429, 500, 502, 503, 504) and attempt < tries - 1:
                time.sleep(1.5 * (attempt + 1))
                continue
            raise
        except (urllib.error.URLError, TimeoutError):
            if attempt < tries - 1:
                time.sleep(1.5 * (attempt + 1))
                continue
            raise
    raise RuntimeError("unreachable")


def valhalla(path, payload):
    return post_json(
        f"https://api.stadiamaps.com{path}?api_key={KEY}",
        json.dumps(payload).encode(),
        {"Content-Type": "application/json"},
    )


# ---------------------------------------------------------------- GPX parsing


def parse_gpx(path):
    root = ET.parse(path).getroot()
    stops = []
    for wpt in root.findall("gpx:wpt", NS):
        cp = wpt.find("gpx:extensions/nb:checkpoint", NS)

        def nb(tag, default=""):
            return cp.findtext(f"nb:{tag}", default=default, namespaces=NS) if cp is not None else default

        stops.append(
            {
                "name": wpt.findtext("gpx:name", default="", namespaces=NS),
                "desc": wpt.findtext("gpx:desc", default="", namespaces=NS),
                "lat": float(wpt.get("lat")),
                "lng": float(wpt.get("lon")),
                "order": int(nb("order", "0")),
                "terrain": nb("terrain"),
                "points": int(nb("points", "0")),
                "challenge": nb("is_challenge").lower() == "true",
            }
        )
    stops.sort(key=lambda s: s["order"])
    return stops


def haversine(a, b):
    r = 6371000.0
    p1, p2 = math.radians(a["lat"]), math.radians(b["lat"])
    dphi = p2 - p1
    dl = math.radians(b["lng"] - a["lng"])
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


# ------------------------------------------------------- travel-time cache/API

_times = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}


def key_of(a, b):
    ka = f"{a['lat']:.5f},{a['lng']:.5f}"
    kb = f"{b['lat']:.5f},{b['lng']:.5f}"
    return "|".join(sorted((ka, kb)))


def fetch_leg(a, b):
    data = valhalla(
        "/route/v1",
        {
            "locations": [
                {"lat": a["lat"], "lon": a["lng"]},
                {"lat": b["lat"], "lon": b["lng"]},
            ],
            "costing": COSTING,
            "costing_options": COSTING_OPTIONS,
            "directions_options": {"units": "kilometers"},
        },
    )
    s = data["trip"]["summary"]
    return float(s["time"]), float(s["length"])


def prefetch(pairs):
    todo = [(a, b) for a, b in pairs if key_of(a, b) not in _times]
    if not todo:
        return
    print(f"consultando {len(todo)} tramos a Valhalla...")
    done = [0]

    def work(pair):
        try:
            secs, km = fetch_leg(*pair)
        except Exception as exc:  # noqa: BLE001 - one bad leg must not stop the plan
            print(f"  tramo fallido: {exc}")
            return
        with _lock:
            _times[key_of(*pair)] = [secs, km]
            done[0] += 1
            if done[0] % 200 == 0:
                print(f"  {done[0]}/{len(todo)}")

    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(work, todo))
    save_times()


def save_times():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(_times), encoding="utf-8")


def leg_speed(a, b, km, raw_secs):
    """Pick 60 / 100 / 110 from endpoint terrain and the kind of road Valhalla used."""
    raw = (km / (raw_secs / 3600.0)) if raw_secs and raw_secs > 0 and km > 0 else 50.0
    dirt = a.get("terrain") == "dirt" or b.get("terrain") == "dirt"
    if raw >= HWY_RAW_KMH:
        return SPEED_HWY_KMH
    if dirt or raw < DIRT_RAW_KMH:
        return SPEED_DIRT_KMH
    return SPEED_PAVE_KMH


def ride(a, b):
    """Rally-pace minutes and km between two points."""
    k = key_of(a, b)
    hit = _times.get(k)
    if hit is None:
        try:
            hit = list(fetch_leg(a, b))
            _times[k] = hit
        except Exception:  # noqa: BLE001 - fall back to a straight-line estimate
            d = haversine(a, b) / 1000 * 1.35
            hit = [d / 45 * 3600, d]
    raw_secs, km = hit
    if km <= 0:
        return 0.0, 0.0
    return km / leg_speed(a, b, km, raw_secs) * 60.0, km


# ------------------------------------------------------------- OSM services

_pois = json.loads(POI_CACHE.read_text(encoding="utf-8")) if POI_CACHE.exists() else {}
OVERPASS = "https://overpass-api.de/api/interpreter"
FILTERS = {
    "fuel": '["amenity"="fuel"]',
    "hotel": '["tourism"~"^(hotel|motel|guest_house|hostel)$"]',
}


def overpass(kind, lat, lng, radius_km):
    ck = f"{kind}:{lat:.3f},{lng:.3f}:{radius_km}"
    if ck in _pois:
        return _pois[ck]
    query = (
        f"[out:json][timeout:60];nwr{FILTERS[kind]}"
        f"(around:{int(radius_km * 1000)},{lat},{lng});out center 60;"
    )
    body = urllib.parse.urlencode({"data": query}).encode()
    # Overpass answers 406 without a real User-Agent and form content type.
    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "RiderLab rally planner (contacto: riderlab)",
    }
    found, ok = [], False
    for attempt in range(3):
        try:
            data = post_json(OVERPASS, body, headers, tries=1)
            for el in data.get("elements", []):
                la = el.get("lat") or (el.get("center") or {}).get("lat")
                lo = el.get("lon") or (el.get("center") or {}).get("lon")
                if la is None or lo is None:
                    continue
                tags = el.get("tags", {})
                found.append(
                    {
                        "id": f"{el.get('type')}/{el.get('id')}",
                        "name": tags.get("name")
                        or ("Gasolinera" if kind == "fuel" else "Hotel sin nombre"),
                        "brand": tags.get("brand", ""),
                        "lat": la,
                        "lng": lo,
                    }
                )
            ok = True
            break
        except Exception as exc:  # noqa: BLE001
            if attempt == 2:
                print(f"  Overpass {kind} fallo: {exc}")
            else:
                time.sleep(2 * (attempt + 1))
    if ok:  # never cache a failed lookup as "nothing here"
        _pois[ck] = found
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        POI_CACHE.write_text(json.dumps(_pois, ensure_ascii=False), encoding="utf-8")
    return found


def nearest_service(kind, anchor, used, radius_km):
    for radius in (radius_km, radius_km * 2, radius_km * 4):
        cands = [c for c in overpass(kind, anchor["lat"], anchor["lng"], radius) if c["id"] not in used]
        if cands:
            best = min(cands, key=lambda c: haversine(anchor, c))
            return {
                **best,
                "kind": kind,
                "desc": "",
                "terrain": "pavement",
                "points": 0,
                "order": 0,
                "away_km": round(haversine(anchor, best) / 1000, 1),
            }
    return None


# ------------------------------------------------------------- loop ordering


def tour_time(order, mins):
    """Closed loop: node 0 is the depot and we always come back to it."""
    t = sum(mins[order[k]][order[k + 1]] for k in range(len(order) - 1))
    return t + mins[order[-1]][order[0]]


def nearest_neighbour(ids, mins, start_at=0):
    order = [ids[start_at]]
    left = [i for i in ids if i != order[0]]
    while left:
        nxt = min(left, key=lambda j: mins[order[-1]][j])
        order.append(nxt)
        left.remove(nxt)
    return order


def improve(order, mins, deadline):
    """2-opt plus Or-opt; the depot stays pinned at position 0."""
    best = order[:]
    best_t = tour_time(best, mins)
    moved = True
    while moved and time.time() < deadline:
        moved = False
        for i in range(1, len(best) - 1):
            for j in range(i + 1, len(best)):
                cand = best[:i] + best[i : j + 1][::-1] + best[j + 1 :]
                t = tour_time(cand, mins)
                if t < best_t - 1e-6:
                    best, best_t, moved = cand, t, True
        for size in (1, 2, 3):
            for i in range(1, len(best) - size + 1):
                chunk = best[i : i + size]
                rest = best[:i] + best[i + size :]
                for k in range(1, len(rest) + 1):
                    cand = rest[:k] + chunk + rest[k:]
                    t = tour_time(cand, mins)
                    if t < best_t - 1e-6:
                        best, best_t, moved = cand, t, True
                        break
                else:
                    continue
                break
    return best, best_t


def best_loop(ids, mins, budget_s=25):
    deadline = time.time() + budget_s
    order, t = improve(nearest_neighbour(ids, mins), mins, deadline)
    for seed in (1, len(ids) // 3, 2 * len(ids) // 3):
        if seed >= len(ids):
            continue
        cand = nearest_neighbour(ids, mins, seed)
        cand = [ids[0]] + [x for x in cand if x != ids[0]]
        cand, ct = improve(cand, mins, deadline)
        if ct < t:
            order, t = cand, ct
    return order, t


# --------------------------------------------------------------- simulation


def simulate(order, nodes, mins, kms, fast=True, used_fuel=None, used_hotel=None):
    """Ride the loop against the clock, inserting refuels, meals and the night.

    Returns (plan, info). info['ok'] is False when the schedule breaks a window.
    """
    used_fuel = set() if used_fuel is None else used_fuel
    used_hotel = set() if used_hotel is None else used_hotel
    depot = nodes[order[0]]
    plan = [
        {
            "kind": "depot",
            "name": depot["name"],
            "desc": "Salida",
            "lat": depot["lat"],
            "lng": depot["lng"],
            "terrain": "pavement",
            "points": 0,
            "orig": 0,
            "leg_min": 0.0,
            "leg_km": 0.0,
            "day": 1,
            "arrive": SAT_START,
        }
    ]
    day, clock, tank_km = 1, SAT_START, 0.0
    meals = {1: False, 2: False}
    cur = depot
    queue = list(order[1:]) + [order[0]]
    pos = 0

    while pos < len(queue):
        idx = queue[pos]
        nxt = nodes[idx]
        last = pos == len(queue) - 1
        leg_min, leg_km = ride(cur, nxt)

        # Refuel before a leg that would push us past the tank window.
        if tank_km + leg_km > FUEL_TARGET_KM:
            station = nearest_service("fuel", cur, used_fuel, 12) if not fast else None
            if station is None:
                # Still mark the refuel; the rider picks the pump on site.
                station, in_min, in_km = _fast_fuel(cur), FUEL_DETOUR_MIN, FUEL_DETOUR_KM
            else:
                in_min, in_km = ride(cur, station)
            if station:
                used_fuel.add(station["id"])
                clock += in_min / 60
                dwell = FUEL_MIN
                meal_note = ""
                if not meals[day] and clock >= (MEAL_SAT_AFTER if day == 1 else MEAL_SUN_AFTER):
                    dwell += MEAL_SAT_MIN if day == 1 else MEAL_SUN_MIN
                    meals[day] = True
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
                        "day": day,
                        "arrive": clock,
                        "dwell_min": dwell,
                        "tank_km": round(tank_km + in_km, 1),
                    }
                )
                clock += dwell / 60
                cur, tank_km = station, 0.0
                leg_min, leg_km = ride(cur, nxt)

        arrival = clock + leg_min / 60

        # Saturday curfew: if this checkpoint no longer scores, close the day.
        if day == 1 and not last and arrival > SAT_CUTOFF:
            hotel = nearest_service("hotel", cur, used_hotel, 25) if not fast else None
            h_min, h_km = (
                ride(cur, hotel) if hotel else (HOTEL_LEG_EST_MIN, HOTEL_LEG_EST_KM)
            )
            clock += h_min / 60
            plan.append(
                {
                    "kind": "hotel",
                    "name": hotel["name"] if hotel else "Hotel por confirmar",
                    "desc": f"Pernocta, a {hotel['away_km']} km del ultimo checkpoint" if hotel else "",
                    "lat": hotel["lat"] if hotel else cur["lat"],
                    "lng": hotel["lng"] if hotel else cur["lng"],
                    "terrain": "pavement",
                    "points": 0,
                    "orig": 0,
                    "leg_min": round(h_min, 1),
                    "leg_km": round(h_km, 1),
                    "day": 1,
                    "arrive": clock,
                }
            )
            if hotel:
                used_hotel.add(hotel["id"])
                cur = hotel
            tank_km += h_km
            day, clock = 2, SUN_START
            continue  # retry the same checkpoint on Sunday

        clock = arrival
        entry = {
            "kind": "depot" if last else "checkpoint",
            "name": nxt["name"],
            "desc": nxt["desc"],
            "lat": nxt["lat"],
            "lng": nxt["lng"],
            "terrain": nxt["terrain"],
            "points": 0 if last else nxt["points"],
            "orig": nxt["order"],
            "leg_min": round(leg_min, 1),
            "leg_km": round(leg_km, 1),
            "day": day,
            "arrive": clock,
            "node": idx,
        }
        tank_km += leg_km
        if not last:
            dwell = CP_MIN
            if not meals[day] and clock >= (MEAL_SAT_AFTER if day == 1 else MEAL_SUN_AFTER):
                dwell += MEAL_SAT_MIN if day == 1 else MEAL_SUN_MIN
                meals[day] = True
                entry["meal"] = True
            entry["dwell_min"] = dwell
            clock += dwell / 60
        plan.append(entry)
        cur = nxt
        pos += 1

    finish = plan[-1]["arrive"]
    night = next((e for e in plan if e["kind"] == "hotel"), None)
    info = {
        "finish": finish,
        "day2": day == 2,
        "hotel_arrive": night["arrive"] if night else None,
        "ok": day == 2 and finish <= SUN_DEADLINE and (night is None or night["arrive"] <= HOTEL_LIMIT),
        "over_min": max(0.0, (finish - SUN_DEADLINE) * 60),
    }
    return plan, info


_FAST_FUEL = {}


def _fast_fuel(anchor):
    """Cheap stand-in during the selection loop: a station right on the spot."""
    k = f"{anchor['lat']:.3f},{anchor['lng']:.3f}"
    if k not in _FAST_FUEL:
        _FAST_FUEL[k] = {
            "id": "fast/" + k,
            "name": "Recarga de gasolina",
            "brand": "",
            "lat": anchor["lat"],
            "lng": anchor["lng"],
            "away_km": 0.0,
        }
    return _FAST_FUEL[k]


# ------------------------------------------------------------------- main


def main():
    stops = parse_gpx(SRC)
    nodes = [DEPOT] + stops
    n = len(nodes)
    print(f"{len(stops)} checkpoints | inicio/meta {DEPOT['lat']}, {DEPOT['lng']}")

    prefetch([(nodes[i], nodes[j]) for i in range(n) for j in range(i + 1, n)])
    mins = [[0.0] * n for _ in range(n)]
    kms = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            m, k = ride(nodes[i], nodes[j])
            mins[i][j] = mins[j][i] = m
            kms[i][j] = kms[j][i] = k
    save_times()

    budget_h = (SAT_CUTOFF - SAT_START) + (SUN_DEADLINE - SUN_START)
    print(f"ventana util: {budget_h:.1f} h de reloj (sab 07-20, dom 06-11)")

    def worst_value(order):
        """Checkpoint giving the fewest points per minute it costs to visit."""
        worst, worst_ratio = None, None
        for k in range(1, len(order)):
            i = order[k]
            prev, nxt = order[k - 1], order[(k + 1) % len(order)]
            saved = mins[prev][i] + mins[i][nxt] - mins[prev][nxt] + CP_MIN
            ratio = nodes[i]["points"] / max(saved, 0.5)
            if worst_ratio is None or ratio < worst_ratio:
                worst, worst_ratio = i, ratio
        return worst

    def shed(order, removed, fast):
        """Drop the least valuable checkpoints until the weekend fits."""
        plan, info = simulate(order, nodes, mins, kms, fast=fast)
        while not info["ok"] and len(order) > 4:
            drop = worst_value(order)
            removed.append(drop)
            order, _ = best_loop([i for i in order if i != drop], mins, 6)
            plan, info = simulate(order, nodes, mins, kms, fast=fast)
        return order, plan, info

    # Start with every checkpoint, then shed the ones that cost the most time
    # per point until the weekend schedule fits.
    order, _ = best_loop(list(range(n)), mins, 25)
    plan, info = simulate(order, nodes, mins, kms, fast=True)
    print(f"con los {len(stops)} CP: llegada {info['finish']:.2f} h, sobran {info['over_min']:.0f} min")

    def reinsert(order, plan, info, removed, fast):
        """Put dropped checkpoints back wherever they cost the least time."""
        for cand in sorted(removed, key=lambda i: -nodes[i]["points"]):
            options = []
            for k in range(1, len(order) + 1):
                trial = order[:k] + [cand] + order[k:]
                t_plan, t_info = simulate(trial, nodes, mins, kms, fast=fast)
                if t_info["ok"]:
                    options.append((t_info["finish"], trial, t_plan, t_info))
            if options:
                _, order, plan, info = min(options, key=lambda o: o[0])
                removed.remove(cand)
        return order, plan, info

    removed = []
    order, plan, info = shed(order, removed, fast=True)
    order, plan, info = reinsert(order, plan, info, removed, fast=True)

    # Re-check with the real gas stations and hotel, then try once more to use
    # up whatever slack the real stops left.
    order, plan, info = shed(order, removed, fast=False)
    order, plan, info = reinsert(order, plan, info, removed, fast=False)
    save_times()

    for e in plan:
        e["arrive_hhmm"] = hhmm(e["arrive"])

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
                "label": "Sabado" if d == 1 else "Domingo",
                "km": round(days[d]["km"], 1),
                "ride_h": round(days[d]["ride"] / 60, 2),
                "stop_h": round(days[d]["stop"] / 60, 2),
                "start": hhmm(SAT_START if d == 1 else SUN_START),
                "end": legs[-1]["arrive_hhmm"],
                "end_name": legs[-1]["name"],
                "checkpoints": days[d]["cp"],
                "points": days[d]["pts"],
            }
        )

    got = sum(e["points"] for e in plan)
    avail = sum(s["points"] for s in stops)
    total_km = sum(e["leg_km"] for e in plan)
    total_ride = sum(e["leg_min"] for e in plan)
    fuel_stops = [e for e in plan if e["kind"] == "fuel"]
    night = next((e for e in plan if e["kind"] == "hotel"), None)
    visited = [e for e in plan if e["kind"] == "checkpoint"]

    stats = {
        "checkpoints_visited": len(visited),
        "checkpoints_total": len(stops),
        "points": got,
        "points_available": avail,
        "points_pct": round(100 * got / avail, 1),
        "skipped": sorted(nodes[i]["order"] for i in removed),
        "loop_km": round(total_km, 1),
        "ride_h": round(total_ride / 60, 2),
        "stop_h": round(sum(e.get("dwell_min", 0.0) for e in plan) / 60, 2),
        "avg_kmh": round(total_km / (total_ride / 60), 1),
        "finish": hhmm(info["finish"]),
        "hotel": night["name"] if night else None,
        "hotel_arrive": hhmm(night["arrive"]) if night else None,
        "fuel_stops": len(fuel_stops),
        "fuel_max_km": round(max([e["tank_km"] for e in fuel_stops], default=0.0), 1),
        "dirt": sum(1 for e in visited if e["terrain"] == "dirt"),
        "pavement": sum(1 for e in visited if e["terrain"] == "pavement"),
        "depot": f"{DEPOT['lat']}, {DEPOT['lng']}",
        "cp_min": CP_MIN,
        "fuel_min": FUEL_MIN,
        "meal_sat_min": MEAL_SAT_MIN,
        "meal_sun_min": MEAL_SUN_MIN,
        "speed_dirt": SPEED_DIRT_KMH,
        "speed_pave": SPEED_PAVE_KMH,
        "speed_hwy": SPEED_HWY_KMH,
        "windows": f"sab {hhmm(SAT_START)}-{hhmm(SAT_CUTOFF)} | dom {hhmm(SUN_START)}-{hhmm(SUN_DEADLINE)}",
    }
    print(json.dumps(stats, indent=2, ensure_ascii=False))
    for r in day_rows:
        print(
            f"  {r['label']}: {r['km']:6.1f} km  {r['ride_h']:.2f} h rodando  "
            f"{r['start']}->{r['end']}  {r['checkpoints']} CP  {r['points']} pts  fin: {r['end_name']}"
        )

    shapes = {}
    for d in sorted(days):
        pts = [e for e in plan if e["day"] == d]
        if d > 1:
            prev = [e for e in plan if e["day"] == d - 1]
            pts = [prev[-1]] + pts
        shapes[str(d)] = road_shape(pts)

    payload = {"stats": stats, "days": day_rows, "plan": plan, "shapes": shapes}
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "ruta_off_1_optimizada.json").write_text(
        json.dumps(payload, ensure_ascii=False), encoding="utf-8"
    )
    print("->", OUT_DIR / "ruta_off_1_optimizada.json")
    return payload


def hhmm(hours):
    h = int(hours) % 24
    m = int(round((hours - int(hours)) * 60))
    if m == 60:
        h, m = (h + 1) % 24, 0
    return f"{h:02d}:{m:02d}"


def decode_polyline6(encoded):
    coords, lat, lng, i = [], 0, 0, 0
    while i < len(encoded):
        for is_lat in (True, False):
            shift, result = 0, 0
            while i < len(encoded):
                b = ord(encoded[i]) - 63
                i += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            delta = ~(result >> 1) if result & 1 else result >> 1
            if is_lat:
                lat += delta
            else:
                lng += delta
        coords.append((round(lat / 1e6, 6), round(lng / 1e6, 6)))
    return coords


def road_shape(points):
    """Real road geometry through a list of points, honouring the 50-loc limit."""
    shape = []
    for s in range(0, len(points) - 1, MAX_LOCS - 1):
        chunk = points[s : s + MAX_LOCS]
        if len(chunk) < 2:
            break
        try:
            data = valhalla(
                "/route/v1",
                {
                    "locations": [{"lat": p["lat"], "lon": p["lng"]} for p in chunk],
                    "costing": COSTING,
                    "costing_options": COSTING_OPTIONS,
                    "directions_options": {"units": "kilometers"},
                },
            )
        except Exception as exc:  # noqa: BLE001
            print("geometria parcial no disponible:", exc)
            continue
        for leg in data["trip"].get("legs", []):
            shape.extend(decode_polyline6(leg.get("shape", "")))
    return shape


if __name__ == "__main__":
    main()
