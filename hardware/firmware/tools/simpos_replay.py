#!/usr/bin/env python3
"""simpos_replay.py - feed a recorded lap to a RiderLab Metrica logger (fw >= 0.6.5-simpos) as
simulated GNSS fixes over the USB serial console, while logging everything the logger prints.

Firmware protocol (0.6.5-simpos):
  SIMPOS ON | SIMPOS OFF | SIMPOS?
  P <utc_ms> <lat_e7> <lon_e7> <hmsl_mm> <gspeed_mm_s> <head_e5> <hacc_mm> <nsv>   (no echo)
No P line for > 2.5 s = fix lost on the logger. Sessions recorded with SIMPOS are marked sim and
never uploaded.

Source lap: b029 (2026-10-09, 10 Hz), indices 103..2522 (moving part, ~1401 m, starts/ends ~70 m
after S/F, 7.8 m apart -> bridged so the loop is continuous). By default the 25 s stop the rider made
on the S/F line inside that lap is removed (--keep-stops to keep it).

--laps N = N passes over the loop. The loop starts after S/F, so N passes cross S/F N times:
the first crossing starts lap 1, so N passes give N-1 timed laps.
--speed X = rider X times faster (10 Hz kept, utc_ms +100 ms per fix, ground speed x X).

Example:
  python simpos_replay.py --port COM8 --laps 3 --speed 1 --lead-in 10 --tail 25 --log run.log
"""
import argparse, json, math, os, re, sys, threading, time

try:
    import serial
except ImportError:
    sys.exit("pyserial missing: python -m pip install pyserial")

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SRC = os.path.join(os.path.dirname(HERE), "riderlab-rides-export", "export-20261009", "azure",
                           "unpaired", "3876d0c9-b029-28d6-c92d-d0c92df47466", "gnss.ndjson")
KY = 110760.0  # m/deg lat at ~20.67 N (only used for bridging distances)


def load_loop(path, i0, i1, keep_stops):
    with open(path, encoding="utf-8") as f:
        rows = [json.loads(l) for l in f if l.strip()]
    pts = rows[i0:i1 + 1]
    if not keep_stops:  # drop stationary samples (< 0.5 m/s) beyond the first second of each stop
        out, run = [], 0
        for p in pts:
            if p["speed_mps"] < 0.5:
                run += 1
                if run > 10:
                    continue
            else:
                run = 0
            out.append(p)
        removed = len(pts) - len(out)
        pts = out
    else:
        removed = 0
    # bridge end -> start so the loop closes (linear, at the mean of both speeds)
    a, b = pts[-1], pts[0]
    kx = KY * math.cos(math.radians(a["lat"]))
    gap = math.hypot((b["lng"] - a["lng"]) * kx, (b["lat"] - a["lat"]) * KY)
    v = max(0.5, (a["speed_mps"] + b["speed_mps"]) / 2)
    nb = max(0, int(math.ceil(gap / (v * 0.1))) - 1)
    hd = math.degrees(math.atan2((b["lng"] - a["lng"]) * kx, (b["lat"] - a["lat"]) * KY)) % 360
    bridge = []
    for k in range(1, nb + 1):
        t = k / (nb + 1)
        bridge.append({"lat": a["lat"] + (b["lat"] - a["lat"]) * t, "lng": a["lng"] + (b["lng"] - a["lng"]) * t,
                       "alt": a["alt"] + (b["alt"] - a["alt"]) * t, "speed_mps": v, "heading": hd,
                       "acc_m": max(a["acc_m"], b["acc_m"]), "sats": min(a["sats"], b["sats"])})
    return pts, bridge, removed, gap


def interp(seq, x):
    """seq: list of samples (cyclic within one pass), x: fractional index."""
    i = int(math.floor(x))
    t = x - i
    a = seq[min(i, len(seq) - 1)]
    b = seq[min(i + 1, len(seq) - 1)]
    dh = ((b["heading"] - a["heading"] + 540) % 360) - 180
    return {"lat": a["lat"] + (b["lat"] - a["lat"]) * t, "lng": a["lng"] + (b["lng"] - a["lng"]) * t,
            "alt": a["alt"] + (b["alt"] - a["alt"]) * t,
            "speed_mps": a["speed_mps"] + (b["speed_mps"] - a["speed_mps"]) * t,
            "heading": (a["heading"] + dh * t) % 360, "acc_m": a["acc_m"], "sats": a["sats"]}


def pline(utc_ms, s, speed_mul):
    return "P %d %d %d %d %d %d %d %d\n" % (
        utc_ms % 86400000, round(s["lat"] * 1e7), round(s["lng"] * 1e7), round(s["alt"] * 1000),
        max(0, round(s["speed_mps"] * speed_mul * 1000)), round((s["heading"] % 360) * 1e5),
        max(0, round(s["acc_m"] * 1000)), int(s["sats"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", default="COM8")
    ap.add_argument("--laps", type=int, default=2, help="passes over the loop (N passes = N-1 timed laps)")
    ap.add_argument("--speed", type=float, default=1.0, help="rider speed multiplier (default 1)")
    ap.add_argument("--lead-in", type=float, default=10.0, help="seconds stopped at the start (auto start test)")
    ap.add_argument("--tail", type=float, default=0.0, help="seconds stopped at the end (auto close test)")
    ap.add_argument("--log", default=None, help="log file (default simpos_<time>.log next to this script)")
    ap.add_argument("--src", default=DEFAULT_SRC, help="gnss.ndjson with the lap (default b029)")
    ap.add_argument("--from-idx", type=int, default=103)
    ap.add_argument("--to-idx", type=int, default=2522)
    ap.add_argument("--keep-stops", action="store_true", help="keep the 25 s stop inside b029")
    ap.add_argument("--cmd", action="append", default=[], help="extra console command before SIMPOS ON (repeatable)")
    ap.add_argument("--post-cmd", action="append", default=[], help="console command after SIMPOS OFF (repeatable)")
    ap.add_argument("--reset", action="store_true", help="EN reset pulse (RTS) on open and wait for boot")
    ap.add_argument("--settle", type=float, default=3.0, help="seconds to keep logging after SIMPOS OFF")
    ap.add_argument("--keep-on", action="store_true", help="do not send SIMPOS OFF at the end")
    ap.add_argument("--no-circuit", action="store_true", help="do not send CIRCUIT OPEN")
    ap.add_argument("--reconnect", type=float, default=60.0, help="seconds to keep retrying if the port drops")
    a = ap.parse_args()
    if a.speed <= 0 or a.laps < 1:
        sys.exit("--speed must be > 0 and --laps >= 1")

    pts, bridge, removed, gap = load_loop(a.src, a.from_idx, a.to_idx, a.keep_stops)
    loop = pts + bridge
    logp = a.log or os.path.join(HERE, time.strftime("simpos_%Y%m%d_%H%M%S.log"))
    out = open(logp, "w", encoding="utf-8")
    t0 = time.time()
    lock = threading.Lock()

    def stamp():
        t = time.time()
        return time.strftime("%H:%M:%S", time.localtime(t)) + ".%03d" % int((t % 1) * 1000)

    def log(s, echo=True):
        with lock:
            line = "%s %8.2f %s" % (stamp(), time.time() - t0, s.rstrip("\r\n"))
            out.write(line + "\n")
            out.flush()
            if echo:
                print(line, flush=True)

    def open_port():
        s_ = serial.Serial()
        s_.port, s_.baudrate, s_.timeout = a.port, 115200, 0.05
        s_.dtr = False  # never toggle EN/IO0 when (re)opening
        s_.rts = False
        s_.open()
        return s_

    ser = open_port()
    stop = threading.Event()
    port_ok = threading.Event()
    port_ok.set()
    reopen_lock = threading.Lock()
    drops = [0]

    def reopen(why):
        # the USB port vanished (unplug / USB reset): keep retrying, P lines are skipped meanwhile
        nonlocal ser
        with reopen_lock:
            if port_ok.is_set():
                port_ok.clear()
                drops[0] += 1
                log("[host] port lost (%s); retrying for %.0f s" % (why, a.reconnect))
                try:
                    ser.close()
                except Exception:
                    pass
            end = time.time() + a.reconnect
            while time.time() < end and not stop.is_set():
                try:
                    ser = open_port()
                    port_ok.set()
                    log("[host] port reopened")
                    return True
                except Exception:
                    time.sleep(0.5)
            return False

    def reader():
        buf = b""
        while not stop.is_set():
            if not port_ok.is_set():
                time.sleep(0.1)
                continue
            try:
                d = ser.read(4096)
            except Exception as e:  # port gone: the writer side reopens it
                port_ok.clear()
                log("[host] serial read error: %s" % e)
                time.sleep(0.2)
                continue
            if not d:
                continue
            buf += d
            while b"\n" in buf:
                l, buf = buf.split(b"\n", 1)
                s = l.decode("utf-8", "replace").rstrip()
                s = re.sub(r'(?i)(pass(word)?|key|secret|sig)=\S+', r'\1=REDACTED', s)
                log("<< " + s)

    th = threading.Thread(target=reader, daemon=True)
    th.start()

    def write(b):
        if not port_ok.is_set() and not reopen("read error"):
            raise serial.SerialException("port %s not back after %.0f s" % (a.port, a.reconnect))
        try:
            ser.write(b)
            return True
        except Exception as e:
            if not reopen(str(e)):
                raise
            return False  # this line is dropped; the logger sees a short gap (fix lost if > 2.5 s)

    def send(c, wait=0.0):
        log("[host] >> " + c)
        write((c + "\n").encode())
        if wait:
            time.sleep(wait)

    log("[host] simpos_replay port=%s src=%s idx=%d..%d pts=%d bridge=%d (gap %.1f m) stop_samples_removed=%d "
        "laps=%d speed=x%.2f lead_in=%.1fs tail=%.1fs" % (a.port, a.src, a.from_idx, a.to_idx, len(pts),
                                                         len(bridge), gap, removed, a.laps, a.speed,
                                                         a.lead_in, a.tail))
    lap_s = len(loop) * 0.1 / a.speed
    log("[host] one pass = %d fixes = %.1f s of track time at x%.2f (expect lap time ~%.0f s)" %
        (len(loop), len(loop) * 0.1, a.speed, lap_s))
    try:
        if a.reset:
            ser.rts = True
            time.sleep(0.12)
            ser.rts = False
            log("[host] EN reset pulse (RTS); waiting 14 s for boot")
            time.sleep(14)
        for c in a.cmd:
            send(c, 1.0)
        if not a.no_circuit:
            send("CIRCUIT OPEN", 3.0)
        send("SIMPOS ON", 1.0)

        # schedule: absolute 10 Hz ticks
        utc0 = int((time.time() % 86400) * 1000) // 100 * 100
        k = 0
        tick0 = time.monotonic()

        def emit(sample, mul):
            nonlocal k
            target = tick0 + k * 0.1
            dt = target - time.monotonic()
            if dt > 0:
                time.sleep(dt)
            if dt < -1.0:  # after a port drop: do not burst the backlog, drop the late fixes
                pass
            else:
                write(pline(utc0 + k * 100, sample, mul).encode())
            k += 1

        still0 = dict(loop[0], speed_mps=0.0)
        n_lead = int(round(a.lead_in * 10))
        log("[host] lead-in %d stationary fixes" % n_lead)
        for _ in range(n_lead):
            emit(still0, 1.0)
        for lap in range(a.laps):
            log("[host] pass %d/%d start utc_ms=%d" % (lap + 1, a.laps, (utc0 + k * 100) % 86400000))
            x = 0.0
            last_prog = time.monotonic()
            while x < len(loop) - 1e-9:
                emit(interp(loop, x) if x <= len(loop) - 1 else loop[-1], a.speed)
                x += a.speed
                if time.monotonic() - last_prog > 30:
                    last_prog = time.monotonic()
                    log("[host] pass %d progress %.0f%%" % (lap + 1, 100 * x / len(loop)))
        endp = dict(pts[-1] if a.laps else loop[0], speed_mps=0.0)
        n_tail = int(round(a.tail * 10))
        log("[host] laps done; tail %d stationary fixes" % n_tail)
        for _ in range(n_tail):
            emit(endp, 1.0)
        log("[host] sent %d P lines in %.1f s (port drops=%d)" % (k, time.monotonic() - tick0, drops[0]))
        send("SIMPOS?", 1.0)
        send("CIRCUIT", 1.5)
        send("AUTO?", 1.0)
        if not a.keep_on:
            send("SIMPOS OFF", 1.0)
        for c in a.post_cmd:
            send(c, 1.0)
        time.sleep(a.settle)
        send("SIMPOS?", 1.5)
    except KeyboardInterrupt:
        log("[host] interrupted")
        if not a.keep_on:
            try:
                send("SIMPOS OFF", 1.0)
            except Exception:
                pass
    finally:
        stop.set()
        th.join(1.0)
        ser.close()
        log("[host] done, log=%s" % logp)
        out.close()


if __name__ == "__main__":
    main()
