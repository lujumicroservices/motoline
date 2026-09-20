"""Generate Play / App Store QR codes for the RiderLab public site."""
from __future__ import annotations

import json
import os
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_H

HERE = Path(__file__).resolve().parent
STORE = json.loads((HERE / "store.json").read_text(encoding="utf-8"))
ORIGIN = STORE["publicOrigin"].rstrip("/")
OUT = Path(os.environ.get("RL_QR_OUT", HERE / "img"))


def write_qr(url: str, dest: Path) -> None:
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=14,
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0e1013", back_color="#ffffff")
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    print(f"Wrote {dest} -> {url}")


def main() -> None:
    write_qr(f"{ORIGIN}/go/android", OUT / "qr-android.png")
    write_qr(f"{ORIGIN}/go/ios", OUT / "qr-ios.png")
    write_qr(f"{ORIGIN}/go/apk", OUT / "qr-apk.png")
    write_qr(f"{ORIGIN}/simm", OUT / "qr-simm.png")


if __name__ == "__main__":
    main()
