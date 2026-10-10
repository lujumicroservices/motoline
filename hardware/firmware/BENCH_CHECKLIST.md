# Bench checklist — Fase 0

Physical stack: Basic → M135 → Battery 13.2 → Bottom Base (`switch=0`).
DIP measured (ancla 2026-10-08): **RXD→G16**, **TXD→G12**, **PPS→G34**. USB-C on Basic only.
Earlier note: TXD=4→G35. Trust `PINSCAN` / BtnB-at-boot (`HI edges>0` = NEO_TXD).
Never route the TXD bank to **G0** (strapping — board may not boot). **G12** is also
strapping but this M135+Basic boots with TXD→G12; if yours will not, use G17 or G15.

## Build

```bash
cd hardware/firmware
python -m platformio run
python -m platformio run -t upload   # device plugged in
python -m platformio device monitor -b 115200
```

## Pass criteria (cielo abierto, antena al cielo)

| Check | Pass |
|-------|------|
| Screen boots `riderlab-*` | |
| Link line shows `rx35 115k` (tras configurar) | |
| Arranque: `GNSS cfg ok` (ruta `ddc` o `tx<pin>`); si `no-cmd-path` → banco TXD del DIP en G17/G15/G12 / `PINSCAN` | |
| Serial `GNSS`: `ubx=` sube ~10+ tramas/s, `bad=0`, `hz=10` | |
| GNSS fix within ~2 min outdoors | |
| sats ≥ 6, HDOP printed | |
| PPS count increments ~1/s, dt ≈ 1.000 s, estado `PPS OK` (no `NOISE`) | |
| Boot `i2c scan ...: 0x69 0x76` (BMI270, BMP280) | |
| `imu ok config ok` y \|a\| ≈ 9.8 m/s² | |
| BMP280 0x76 OK, `BARO` da Pa razonable (~82–84 kPa en GDL) | |
| SD: `ok → /riderlab/...` | |
| Bottom Base switch still 0 | |

Do **not** start high-rate logger validation until this sheet passes on hardware.

## Modo ancla (ver ANCHOR.md)

| Check | Pass |
|-------|------|
| `ROLE ANCHOR` → reinicia con banner `ROLE=ANCHOR (reference station)` | |
| Pantalla con insignia naranja **ANCLA**, Wi‑Fi apagado | |
| `ANT_H 1.50` y `REF ...` persisten tras reinicio (`REF?`) | |
| Arranca sola con fix; `anchor_err.ndjson` y `anchor_summary.json` crecen | |
| Golpe a la mesa → `GOLPE - NO TOCAR` y marca `bump` | |
| Tras ≥3 min a cielo abierto → `LISTA` | |
| Cortar energía y volver → sesión nueva con `prev_session` | |
| `ROLE RIDER` vuelve al comportamiento de moto | |
