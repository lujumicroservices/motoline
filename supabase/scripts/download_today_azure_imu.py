#!/usr/bin/env python3
"""Download RiderLab Azure IMU replay blobs for today's copied rides.

Usage:
    python supabase/scripts/download_today_azure_imu.py
"""
from __future__ import annotations

import gzip
import io
import json
import os
import subprocess
import tarfile
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

REPO = Path(__file__).resolve().parents[2]
ACCOUNT = "riderlabimu"
CONTAINER = "lean-replay"
RG = "rg-riderlab"
DEST_USER = "a9fb7d65-f80f-4bbb-820a-fa88f4d7b2e5"
TZ = ZoneInfo("America/Mexico_City")


def az_json(args: list[str]) -> object:
    cmd = ["az.cmd" if os.name == "nt" else "az", *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"az failed {proc.returncode}")
    text = proc.stdout.strip()
    return json.loads(text) if text else None


def az_text(args: list[str]) -> str:
    cmd = ["az.cmd" if os.name == "nt" else "az", *args]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"az failed {proc.returncode}")
    return proc.stdout.strip()


def account_key() -> str:
    return az_text([
        "storage", "account", "keys", "list",
        "--account-name", ACCOUNT,
        "--resource-group", RG,
        "--query", "[0].value",
        "-o", "tsv",
    ])


def blob_exists(key: str, name: str) -> dict | None:
    items = az_json([
        "storage", "blob", "list",
        "--account-name", ACCOUNT,
        "--container-name", CONTAINER,
        "--account-key", key,
        "--prefix", name,
        "-o", "json",
    ])
    if not isinstance(items, list):
        return None
    for item in items:
        if item.get("name") == name:
            return item
    return None


def download_blob(key: str, name: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    az_text([
        "storage", "blob", "download",
        "--account-name", ACCOUNT,
        "--container-name", CONTAINER,
        "--account-key", key,
        "--name", name,
        "--file", str(dest),
        "--overwrite", "true",
        "-o", "none",
    ])


def copy_blob(key: str, source: str, dest_name: str) -> None:
    az_text([
        "storage", "blob", "copy", "start",
        "--account-name", ACCOUNT,
        "--destination-container", CONTAINER,
        "--destination-blob", dest_name,
        "--source-container", CONTAINER,
        "--source-blob", source,
        "--account-key", key,
        "-o", "none",
    ])


def unpack(gz_path: Path, out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = gzip.decompress(gz_path.read_bytes())
    files: list[str] = []
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tar:
        tar.extractall(out_dir, filter="data")
        files = [m.name for m in tar.getmembers() if m.isfile()]
    meta: dict = {}
    meta_path = out_dir / "meta.json"
    if meta_path.exists():
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    counts = {}
    for name in ("imu.csv", "lean10.csv"):
        p = out_dir / name
        if p.exists():
            counts[name] = max(0, len(p.read_text(encoding="utf-8", errors="replace").splitlines()) - 1)
    return {"files": files, "meta": meta, "counts": counts}


def main() -> int:
    day = datetime.now(TZ).date().isoformat()
    out_root = REPO / "tmp" / "ride-analysis" / day / "azure"
    out_root.mkdir(parents=True, exist_ok=True)

    mapping_path = REPO / "tmp" / "ride-analysis" / day / "emulator_copy.json"
    if not mapping_path.exists():
        raise SystemExit(f"missing {mapping_path} — run the copy SQL first")
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    rows = mapping.get("rows") or mapping
    if isinstance(rows, dict):
        rows = rows.get("rides") or []

    key = account_key()
    report = []
    for row in rows:
        rider = row.get("rider_name") or "rider"
        source_user = row["source_user_id"]
        source_local = row["source_local_id"]
        source_cloud = row.get("source_ride_id")
        dest_local = row["dest_local_id"]
        candidates = [f"{source_user}/{source_local}.sqlite.gz"]
        if source_cloud:
            candidates.append(f"{source_user}/{source_cloud}.sqlite.gz")
        found = None
        blob_name = None
        for name in candidates:
            found = blob_exists(key, name)
            if found:
                blob_name = name
                break
        entry = {
            "rider": rider,
            "title": row.get("title"),
            "source_local_id": source_local,
            "blob": blob_name,
            "bytes": None if not found else found.get("properties", {}).get("contentLength"),
        }
        if not found:
            entry["status"] = "missing"
            report.append(entry)
            print(f"  {rider}: NO Azure blob")
            continue
        dest_dir = out_root / rider.replace(" ", "_") / source_local
        gz_path = dest_dir / "replay.sqlite.gz"
        print(f"  {rider}: downloading {blob_name}")
        download_blob(key, blob_name, gz_path)
        unpacked = unpack(gz_path, dest_dir / "unpacked")
        entry["status"] = "ok"
        entry["unpacked"] = unpacked
        emu_blob = f"{DEST_USER}/{dest_local}.sqlite.gz"
        print(f"  {rider}: copying blob to emulator {emu_blob}")
        copy_blob(key, blob_name, emu_blob)
        entry["emulator_blob"] = emu_blob
        report.append(entry)

    (out_root / "index.json").write_text(
        json.dumps({"date": day, "blobs": report}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Azure IMU: {out_root}")
    for item in report:
        counts = (item.get("unpacked") or {}).get("counts") or {}
        print(
            f"  {item['rider']}: {item['status']}"
            f" imu={counts.get('imu.csv', '—')} lean10={counts.get('lean10.csv', '—')}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
