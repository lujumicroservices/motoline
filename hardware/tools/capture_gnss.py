"""Capture FIX lines from the RiderLab logger over USB serial.

Usage: python capture_gnss.py [COM6] [seconds]
Writes hardware/captures/m5_gnss_live.json
"""

import json
import pathlib
import sys
import time

import serial

PORT = sys.argv[1] if len(sys.argv) > 1 else "COM6"
DURATION = float(sys.argv[2]) if len(sys.argv) > 2 else 90.0
OUT = pathlib.Path(__file__).resolve().parents[1] / "captures" / "m5_gnss_live.json"

FIELDS = ("utc_ms", "lat", "lng", "alt", "speed_mps", "heading", "sats", "hdop")
CASTS = (int, float, float, float, float, float, int, float)


def parse(line):
    parts = line.split(",")
    if len(parts) < 9:
        return None
    try:
        return {k: c(v) for k, c, v in zip(FIELDS, CASTS, parts[1:9])}
    except ValueError:
        return None


def main():
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = 115200
    ser.timeout = 0.5
    ser.dtr = False
    ser.rts = False
    ser.open()

    points = []
    buf = ""
    started = time.time()
    while time.time() - started < DURATION:
        chunk = ser.read(4096)
        if not chunk:
            continue
        buf += chunk.decode("utf-8", "replace")
        while "\n" in buf:
            line, buf = buf.split("\n", 1)
            line = line.strip()
            if not line.startswith("FIX,"):
                continue
            rec = parse(line)
            if rec is None or (rec["lat"] == 0 and rec["lng"] == 0):
                continue
            if points and points[-1]["utc_ms"] == rec["utc_ms"]:
                continue
            points.append(rec)
            print(
                "{:3d} {:.7f} {:.7f} sats={} hdop={}".format(
                    len(points), rec["lat"], rec["lng"], rec["sats"], rec["hdop"]
                ),
                flush=True,
            )
    ser.close()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(points, indent=2), encoding="utf-8")
    print("puntos:", len(points), "->", OUT)


if __name__ == "__main__":
    main()
