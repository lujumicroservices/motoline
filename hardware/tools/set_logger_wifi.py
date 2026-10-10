"""Send Wi-Fi + Azure ingest key to the M5 over USB (no DTR/RTS).

Usage:
  python set_logger_wifi.py COM6 "SSID" "password"
  python set_logger_wifi.py COM6 "SSID1|SSID2" "password" AZURE_KEY
"""

import sys
import time

import serial

PORT = sys.argv[1] if len(sys.argv) > 1 else "COM6"
SSID = sys.argv[2] if len(sys.argv) > 2 else ""
PASS = sys.argv[3] if len(sys.argv) > 3 else ""
KEY = sys.argv[4] if len(sys.argv) > 4 else ""
URL = sys.argv[5] if len(sys.argv) > 5 else ""


def main():
    if not SSID:
        print("usage: set_logger_wifi.py COM6 SSID PASS [AZURE_KEY] [INGEST_URL]")
        sys.exit(2)
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = 115200
    ser.timeout = 0.5
    ser.dtr = False
    ser.rts = False
    ser.open()
    time.sleep(0.2)
    if "|" in SSID:
        ser.write(("WIFI %s|%s\n" % (SSID, PASS)).encode())
    else:
        ser.write(("WIFI %s|%s\n" % (SSID, PASS)).encode())
    print("sent WIFI")
    if KEY:
        if URL:
            ser.write(("AZURE %s|%s\n" % (URL, KEY)).encode())
        else:
            ser.write(("AZURE %s\n" % KEY).encode())
        print("sent AZURE")
    time.sleep(0.4)
    ser.close()


if __name__ == "__main__":
    main()
