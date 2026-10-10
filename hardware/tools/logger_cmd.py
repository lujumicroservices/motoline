"""Send serial commands to the logger and print what it answers.

Usage: python logger_cmd.py COM8 "UPSTAT" ["RIDES" ...] [--wait 3]
"""

import sys
import time

import serial

args = [a for a in sys.argv[1:]]
wait = 3.0
if "--wait" in args:
    i = args.index("--wait")
    wait = float(args[i + 1])
    del args[i : i + 2]
port, cmds = args[0], args[1:]

ser = serial.Serial()
ser.port = port
ser.baudrate = 115200
ser.timeout = 0.3
ser.dtr = False
ser.rts = False
ser.open()
time.sleep(0.3)
ser.reset_input_buffer()
for c in cmds:
    ser.write((c + "\n").encode())
    time.sleep(0.15)
end = time.time() + wait
buf = b""
while time.time() < end:
    buf += ser.read(4096)
ser.close()
for line in buf.decode("utf-8", "replace").splitlines():
    if line.startswith(("gnss ", "FIX,")):
        continue
    print(line)
