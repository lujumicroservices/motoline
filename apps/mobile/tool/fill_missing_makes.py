"""Fill missing OEM makes into catalog.json (NHTSA retries)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Reuse fetch helpers
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_bike_catalog import (  # noqa: E402
    EXTRAS,
    OUT,
    SKIP_MODEL,
    YEAR_FROM,
    YEAR_TO,
    add_range,
    fetch_year,
)
from concurrent.futures import ThreadPoolExecutor, as_completed

MISSING = {
    "INDIAN MOTORCYCLE": "Indian",
    "ROYAL ENFIELD": "Royal Enfield",
    "HUSQVARNA": "Husqvarna",
    "CFMOTO": "CFMoto",
    "ZERO MOTORCYCLES": "Zero",
    "LIVEWIRE": "LiveWire",
    "ENERGICA": "Energica",
    "NORTON": "Norton",
    "NORTON MOTORCYCLES": "Norton",
    "MV AGUSTA MOTOR": "MV Agusta",
    "VICTORY": "Victory",
    "KYMCO": "Kymco",
    "VESPA": "Vespa",
    "CAN-AM": "Can-Am",
    "KEEWAY": "Keeway",
    "MOTO MORINI": "Moto Morini",
    "BIMOTA": "Bimota",
    "SYM": "SYM",
    "JAWA": "Jawa",
    "ITALJET": "Italjet",
    "NIU": "Niu",
    "SURRON": "Sur-Ron",
    "STARK FUTURE": "Stark",
}


def main() -> int:
    payload = json.loads(OUT.read_text(encoding="utf-8"))
    store: dict[str, dict[str, list[int]]] = {}
    for make in payload["makes"]:
        models = {}
        for m in make["models"]:
            models[m["n"]] = list(range(int(m["a"]), int(m["b"]) + 1))
        store[make["name"]] = models

    jobs = [(n, y) for n in MISSING for y in range(YEAR_FROM, YEAR_TO + 1)]
    print(f"filling {len(jobs)} queries…", flush=True)
    done = 0
    with ThreadPoolExecutor(max_workers=6) as pool:
        futs = [pool.submit(fetch_year, make, year) for make, year in jobs]
        for fut in as_completed(futs):
            nhtsa_name, year, models = fut.result()
            brand = MISSING[nhtsa_name]
            for model in models:
                if SKIP_MODEL.search(model):
                    continue
                if "FORCE" in model.upper() and brand == "CFMoto":
                    continue
                add_range(store, brand, model, [year])
            done += 1
            if done % 50 == 0:
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

    payload["makes"] = makes_out
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    n_models = sum(len(m["models"]) for m in makes_out)
    print(f"wrote {OUT} makes={len(makes_out)} models={n_models} bytes={OUT.stat().st_size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
