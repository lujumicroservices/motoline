"""Build assets/bikes/catalog.json from NHTSA vPIC + LATAM extras.

Run: python tool/fetch_bike_catalog.py
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "bikes" / "catalog.json"
NHTSA = "https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/{make}/modelyear/{year}/vehicleType/motorcycle?format=json"
YEAR_FROM, YEAR_TO = 1990, 2026
WORKERS = 10

# Exact NHTSA MakeName → display name. Duplicates merge.
MAKES = {
    "HONDA": "Honda",
    "YAMAHA": "Yamaha",
    "KAWASAKI": "Kawasaki",
    "SUZUKI": "Suzuki",
    "TRIUMPH": "Triumph",
    "BMW": "BMW",
    "DUCATI": "Ducati",
    "KTM": "KTM",
    "KTMMEX": "KTM",
    "HARLEY-DAVIDSON": "Harley-Davidson",
    "HARLEY": "Harley-Davidson",
    "APRILIA": "Aprilia",
    "MOTO GUZZI": "Moto Guzzi",
    "MV AGUSTA MOTOR": "MV Agusta",
    "INDIAN MOTORCYCLE": "Indian",
    "VICTORY": "Victory",
    "ROYAL ENFIELD": "Royal Enfield",
    "HUSQVARNA": "Husqvarna",
    "GASGAS": "GASGAS",
    "BETA": "Beta",
    "SHERCO": "Sherco",
    "BENELLI": "Benelli",
    "BENELLI Q.J. SRL": "Benelli",
    "CFMOTO": "CFMoto",
    "KEEWAY": "Keeway",
    "KYMCO": "Kymco",
    "PIAGGIO": "Piaggio",
    "VESPA": "Vespa",
    "CAN-AM": "Can-Am",
    "ZERO MOTORCYCLES": "Zero",
    "LIVEWIRE": "LiveWire",
    "ENERGICA": "Energica",
    "NORTON": "Norton",
    "NORTON MOTORCYCLES": "Norton",
    "JAWA": "Jawa",
    "BAJAJ AUTO": "Bajaj",
    "BIMOTA": "Bimota",
    "MOTO MORINI": "Moto Morini",
    "FANTIC": "Fantic",
    "SWM": "SWM",
    "ARCH MOTORCYCLE CO": "Arch",
    "BUELL": "Buell",
    "BUELL (EBR)": "Buell",
    "HYOSUNG": "Hyosung",
    "HYOSUNG MOTORS & MACHINERY": "Hyosung",
    "DAELIM MOTOR CO., LTD": "Daelim",
    "KOVE": "Kove",
    "QJMOTOR": "QJMotor",
    "QIANJIANG MOTORCYCLES": "QJMotor",
    "ZHEJIANG QIANJIANG MOTORCYCLE": "QJMotor",
    "LONCIN": "Loncin",
    "MALAGUTI S.P.A.": "Malaguti",
    "ITALJET": "Italjet",
    "CAGIVA MOTOR S.P.A": "Cagiva",
    "PEUGEOT MOTORCYCLES": "Peugeot",
    "SYM": "SYM",
    "GENUINE": "Genuine",
    "GENUINE SCOOTERS": "Genuine",
    "LANCE": "Lance",
    "UNITED MOTORS": "UM",
    "UM MOTORCYCLES": "UM",
    "URAL": "Ural",
    "URAL SIDECARS & SOLOS": "Ural",
    "VENTO": "Vento",
    "NIU": "Niu",
    "SURRON": "Sur-Ron",
    "STARK FUTURE": "Stark",
    "CAKE": "CAKE",
    "DAMON MOTORS": "Damon",
    "LIGHTNING MOTORS CORP": "Lightning",
    "MOTUS MOTORCYCLES": "Motus",
    "BRAMMO": "Brammo",
    "BOSS HOSS": "Boss Hoss",
    "DERBI": "Derbi",
    "ADLY": "Adly",
    "PIAGGIO AND VESPA": "Piaggio",
}

SKIP_MODEL = re.compile(
    r"\b(TRX|SXS|Pioneer|Foreman|Rancher|Recon|Rincon|Rubicon|Talon|"
    r"RZR|Ranger|Maverick|Commander|Outlander|Sportsman|ATV|UTV|"
    r"Side[ -]?by[ -]?Side|Gator)\b",
    re.I,
)

# Mexico / missing-from-NHTSA models: name, year_from, year_to
EXTRAS: dict[str, list[tuple[str, int, int]]] = {
    "Italika": [
        ("FT 125", 2010, 2026),
        ("FT 150", 2010, 2026),
        ("FT 250", 2012, 2026),
        ("DT 125", 2012, 2026),
        ("DT 150", 2012, 2026),
        ("DT 200", 2015, 2026),
        ("DT 250", 2016, 2026),
        ("125Z", 2014, 2026),
        ("150Z", 2014, 2026),
        ("200Z", 2016, 2026),
        ("250Z", 2016, 2026),
        ("Vort-X 200", 2018, 2026),
        ("Vort-X 300", 2020, 2026),
        ("WS 150", 2014, 2026),
        ("WS 175", 2016, 2026),
        ("DM 150", 2015, 2026),
        ("DM 250", 2016, 2026),
        ("Vitalia 125", 2016, 2026),
        ("Vitalia 150", 2016, 2026),
        ("AT 110", 2012, 2026),
        ("AT 125", 2012, 2026),
        ("TC 200", 2018, 2026),
        ("TC 250", 2018, 2026),
        ("Sport 250", 2015, 2026),
        ("W 150", 2014, 2026),
        ("RT 200 GP", 2018, 2026),
        ("GS 150", 2015, 2026),
        ("X 150", 2016, 2026),
        ("150 SZ", 2018, 2026),
        ("200 SZ", 2018, 2026),
        ("Forza 300", 2022, 2026),
        ("Voltaica", 2023, 2026),
    ],
    "Vento": [
        ("Ghost 150", 2015, 2026),
        ("Nitrox 250", 2016, 2026),
        ("Crossfire 250", 2016, 2026),
        ("Tornado 250", 2015, 2026),
        ("Rocketman 250", 2016, 2026),
        ("Ligero 150", 2014, 2026),
        ("Triton 250", 2018, 2026),
        ("Workman 150", 2014, 2026),
        ("Thunderstar 250", 2018, 2026),
        ("Safari 250", 2016, 2026),
        ("Hellcat 250", 2018, 2026),
        ("V-Thunder", 2015, 2026),
    ],
    "Bajaj": [
        ("Pulsar 150", 2010, 2026),
        ("Pulsar 180", 2010, 2024),
        ("Pulsar NS160", 2017, 2026),
        ("Pulsar NS200", 2012, 2026),
        ("Pulsar N160", 2022, 2026),
        ("Pulsar N250", 2021, 2026),
        ("Pulsar RS200", 2015, 2026),
        ("Dominar 250", 2020, 2026),
        ("Dominar 400", 2017, 2026),
        ("Avenger 220", 2012, 2024),
        ("Platina 110", 2010, 2026),
        ("CT 125", 2018, 2026),
    ],
    "TVS": [
        ("Apache RTR 160", 2012, 2026),
        ("Apache RTR 200", 2016, 2026),
        ("Apache RR 310", 2018, 2026),
        ("Raider 125", 2021, 2026),
        ("Ntorq 125", 2018, 2026),
        ("Jupiter", 2014, 2026),
    ],
    "Hero": [
        ("Xpulse 200", 2019, 2026),
        ("Xtreme 160R", 2020, 2026),
        ("Hunk 150", 2010, 2022),
        ("Ignitor", 2012, 2020),
        ("Destini 125", 2018, 2026),
        ("Pleasure", 2010, 2026),
    ],
}


def fetch_year(make: str, year: int) -> tuple[str, int, list[str]]:
    url = NHTSA.format(make=urllib.parse.quote(make), year=year)
    req = urllib.request.Request(url, headers={"User-Agent": "RiderLabCatalog/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=40) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            names = []
            for row in data.get("Results") or []:
                n = (row.get("Model_Name") or "").strip()
                if n and not SKIP_MODEL.search(n):
                    names.append(n)
            return make, year, names
        except Exception:
            time.sleep(0.6 * (attempt + 1))
    return make, year, []


def add_range(store: dict[str, dict[str, list[int]]], brand: str, model: str, years: list[int]) -> None:
    if not years:
        return
    models = store.setdefault(brand, {})
    bucket = models.setdefault(model, [])
    for y in years:
        if y not in bucket:
            bucket.append(y)


def main() -> int:
    jobs = [(nhtsa, year) for nhtsa in MAKES for year in range(YEAR_FROM, YEAR_TO + 1)]
    print(f"fetching {len(jobs)} make-year queries…", flush=True)
    store: dict[str, dict[str, list[int]]] = defaultdict(dict)
    done = 0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futs = [pool.submit(fetch_year, make, year) for make, year in jobs]
        for fut in as_completed(futs):
            nhtsa_name, year, models = fut.result()
            brand = MAKES[nhtsa_name]
            for model in models:
                add_range(store, brand, model, [year])
            done += 1
            if done % 100 == 0:
                print(f"  {done}/{len(jobs)}", flush=True)

    for brand, rows in EXTRAS.items():
        for name, a, b in rows:
            add_range(store, brand, name, list(range(a, b + 1)))

    makes_out = []
    for brand in sorted(store, key=str.casefold):
        models_out = []
        for name, years in sorted(store[brand].items(), key=lambda kv: kv[0].casefold()):
            years = sorted(set(years))
            if not years:
                continue
            models_out.append({"n": name, "a": years[0], "b": years[-1]})
        if models_out:
            makes_out.append({"name": brand, "models": models_out})

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {"source": "nhtsa+extras", "yearFrom": YEAR_FROM, "yearTo": YEAR_TO, "makes": makes_out}
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    n_models = sum(len(m["models"]) for m in makes_out)
    print(f"wrote {OUT}  makes={len(makes_out)} models={n_models} bytes={OUT.stat().st_size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
