"""List and download logger sessions from the device SD over USB serial.

Usage:
  python pull_sessions.py [COM6]                    # list only
  python pull_sessions.py [COM6] --all              # download every file
  python pull_sessions.py [COM6] --file <sid/name>  # download one file
"""

import pathlib
import sys
import time

import serial

PORT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "COM6"
FETCH = "--all" in sys.argv
ONE = sys.argv[sys.argv.index("--file") + 1] if "--file" in sys.argv else None
OUT = pathlib.Path(__file__).resolve().parents[1] / "captures" / "sessions"


def open_port():
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = 115200
    ser.timeout = 0.5
    ser.dtr = False
    ser.rts = False
    ser.open()
    return ser


def read_until(ser, marker, timeout):
    """Collect raw text until marker appears; status lines are filtered by caller."""
    buf = ""
    deadline = time.time() + timeout
    while time.time() < deadline:
        chunk = ser.read(8192)
        if chunk:
            buf += chunk.decode("utf-8", "replace")
            if marker in buf:
                break
    return buf


def strip_status(text):
    keep = []
    for line in text.splitlines():
        if line.startswith(("gnss ", "FIX,", "[")):
            continue
        keep.append(line)
    return "\n".join(keep)


def fetch(ser, name, size):
    ser.reset_input_buffer()
    ser.write(("DUMP " + name + "\n").encode())
    # 115200 baud moves ~11 kB/s, so allow generous time for multi-MB files.
    raw = read_until(ser, "DUMP END", 90 + size / 8000)
    start = raw.find("\n", raw.find("DUMP BEGIN"))
    end = raw.find("DUMP END")
    if start < 0 or end < 0:
        print("fallo al descargar", name)
        return
    body = strip_status(raw[start + 1 : end]).strip("\n")
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / name.replace("/", "__")
    dest.write_text(body, encoding="utf-8")
    print("guardado", dest, len(body), "bytes de", size)


def main():
    ser = open_port()

    if ONE:
        fetch(ser, ONE, 2_000_000)
        ser.close()
        return

    ser.reset_input_buffer()
    ser.write(b"LIST\n")
    raw = strip_status(read_until(ser, "LIST END", 20))

    files = []
    for line in raw.splitlines():
        if line.startswith("L "):
            parts = line.split()
            if len(parts) >= 3:
                files.append((parts[1], int(parts[2])))

    if not files:
        print("No hay sesiones en /riderlab/sessions (nunca se grabo con BtnA).")
        ser.close()
        return

    print("Sesiones en la SD:")
    for name, size in files:
        print("  {:<48} {:>9} bytes".format(name, size))

    if not FETCH:
        print("\nUsa --all para descargarlas.")
        ser.close()
        return

    for name, size in files:
        if size > 0:
            fetch(ser, name, size)

    ser.close()


if __name__ == "__main__":
    main()
