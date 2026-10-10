# Firmware — RiderLab logger

Stack: **Basic** → **M135** → **Battery 13.2** → Bottom Base (`switch=0`).

DIP (measured): ancla 2026-10-08 — bank **RXD→G16** (host RX ← NEO_TXD), bank
**TXD→G12** (host TX → NEO_RXD), **PPS→G34**. Silkscreen is from the receiver's side.
Earlier unit note: TXD=4→G35. G12 boots OK here; if a unit won't boot, move TXD to G17/G15.
Hold **BtnB at boot** (or serial `PINSCAN`) to confirm.

## Build / flash

```bash
cd hardware/firmware
python -m platformio run
python -m platformio run -t upload
python -m platformio device monitor -b 115200
```

## Roles (firmware 0.5.0-anchor)

Un firmware, dos roles en NVS: **RIDER** (moto, default) y **ANCHOR** (estación de referencia,
ver [ANCHOR.md](ANCHOR.md)). Cambiar: serial `ROLE ANCHOR` / `ROLE RIDER`, o encender con
**A + C** presionados. Ambos roles configuran igual el receptor (10 Hz multi-GNSS, UBX
NAV-PVT/SAT/DOP, UART 115200).

## Buttons

| Button | RIDER | ANCHOR |
|--------|-------|--------|
| A | Start / stop session | Start / stop (arranca solo con fix) |
| B | Menú | Menú |
| C | Subir sesión (parado) · `MARK` (grabando) · **mantener 1 s** = `COLOC` inicio/fin | Página posición/calidad |
| A+C al encender | Selector de rol | Selector de rol |
| B al encender | Escaneo de pines GNSS | Escaneo de pines GNSS |

En ANCHOR la pantalla se atenúa a los 3 min; el primer botón solo la despierta.

## Serial provisioning

```
WIFI myssid|mypass
PAIR <device_id>|<device_secret>|<ingest_https_url>
KEEPSD ON            # no borrar la sesión de la SD tras subirla (ancla: siempre)
```

Más comandos: `HELP`, `STATUS`, `ROLE`, `ANT_H`, `REF ...`, `REF FROM AVG`, `MARK`, `COLOC START|END`,
`GNSS`, `GNSSCFG`, `PINSCAN`, `IMU`, `BARO` (detalle en ANCHOR.md).

## SD layout

`/riderlab/sessions/<session_id>/{manifest.json,gnss.ndjson,pvt.ndjson,sat.ndjson,dop.ndjson,imu.ndjson,baro.ndjson,quality.ndjson,marks.ndjson}`
+ en ANCHOR `anchor_err.ndjson` y `anchor_summary.json`.

Partición: `default_16MB.csv` (app 6.25 MB; NVS en el mismo offset, la config se conserva).

## Post-proceso

```bash
python tools/anchor_correct.py --anchor SES_ANCLA --rider SES_MOTO --out salida --rider-ant-h 1.0
python -m unittest tools/test_anchor_correct.py -v
```

See [BENCH_CHECKLIST.md](BENCH_CHECKLIST.md) before trusting rates outdoors.
