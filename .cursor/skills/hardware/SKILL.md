---
name: hardware
description: Resume and continue the RiderLab hardware/logger subproject (GNSS, IMU, M5Stack M135, BOM, prototype, circuit racing line). Use when the user says /hardware, retoma hardware, pausa hardware, prototipo, logger, M9N, M135, BOM de sensores, hardware de moto, AiM, o pide diseñar/comprar el dispositivo que reemplaza al teléfono.
---

# Hardware subproject

Work lives in `hardware/`. This is a **separate lane** from shop, landing, and Play.

## Resume (every hardware turn)

1. Read `hardware/STATUS.md`.
2. Read `hardware/CONTEXT.md` and `hardware/BOM.md`.
3. Read `hardware/DECISIONS.md` before proposing a different architecture or BOM.
4. Continue from **Siguiente paso** in STATUS. Do not re-ask closed decisions.
5. The Solo 2 comparison is closed. Use the section below and `hardware/comparacion-solo-2.pdf`. Do not re-derive it.

If STATUS and the user conflict, follow the user, then update STATUS.

## Pause

When the user says **pausa hardware**, ends the hardware thread, or a decision lands:

Update `hardware/STATUS.md` (date, what changed, next step, open questions). Update `BOM.md` / `DECISIONS.md` only if those actually changed.

Keep STATUS short.

## Honesty

Prototype is a **maker M5Stack stack** (Basic v2.7 on top of M135), not a sealed AiM dash. Do not generate polished commercial renders. Do not imply RTK or <0.5 m accuracy on the current BOM.

## Comparison vs AiM Solo 2 (closed 2026-09-26)

Human-facing write-up: `hardware/comparacion-solo-2.pdf`. Do not reopen this comparison, re-search the specs, or tighten the line expectation unless the user asks or the BOM changes.

Reference competitor is **AiM Solo 2**. Solo 2 DL is the same GNSS and IMU plus ECU/CAN, which this BOM does not copy. The phone is not the hardware competitor.

Same sensor class. Solo 2 is a finished lap timer. The prototype is an unmeasured maker stack. Firmware does not exist, so 25 Hz logging, lap time, and delta are chip capability, not measured behavior.

| | Prototype (M135 + Basic v2.7) | AiM Solo 2 |
|---|---|---|
| What it is | Maker stack in a project box | Sealed bar-mounted lap timer |
| Price | ~$128 parts (catalog 19 Sep 2026) | €430 ex VAT on the AiM store; a US dealer listed ~$499 on 26 Sep 2026 |
| GNSS | u-blox NEO-M9N, L1, GPS + GLONASS + Galileo + BeiDou, up to 25 Hz | 25 Hz, same 4 constellations. AiM does not publish the chip |
| Line | u-blox: 2.0 m CEP, 1.5 m CEP with SBAS. This BOM expects **1–2.5 m** until measured on the circuit | AiM: generally under 0.5 m. That is their claim. Do not repeat it as ours |
| IMU | BMI270, 6-axis, up to ±16 g. Plan ~50 Hz, same as the phone | 100 Hz, ±5 g accelerometer + gyro. Roll, pitch, yaw |
| Display | 2.0" IPS 320×240, 853 nit, 54 mm square, 3 buttons | Graphical 238×99, up to 5 pages, 10 RGB LEDs |
| Log | Basic microSD. No file format yet | 4 GB internal + Wi-Fi to RaceStudio 3 |
| Laps | Lap and delta are on the screen list. Not built | Track database, auto recognition, sectors, delta, predictive. Lap time to 0.01 s |
| Enclosure | IP65 project box, 3 m magnetic SMA antenna + ground plane | 98.0×73.7×30.2 mm, 240 g, IP67, internal antenna, AiM mounts |
| Power | Battery 13.2 (1500 mAh), or bike USB 5 V, or 12→5 V buck. Not all three | 9–15 V from the bike + internal lithium battery |

Line, in the order CONTEXT already uses:

1. **Density.** Tie if firmware sets the M9N to 25 Hz. The chip can do it. Nothing asks for it yet.
2. **Continuity and jitter.** Solo 2 is ahead on paper. 0.5 m is tighter than the M9N CEP. The external antenna on a high, clear point is this BOM's lever. Until it is mounted on that circuit, keep 1–2.5 m.
3. **Repeatability.** Solo 2 already ties position to a known track. On the prototype that is RiderLab software, and it is not written.
4. **Lean.** Both have a 6-axis IMU. 50 Hz is enough for lean L/R. 100 Hz is extra margin for lap time, which is Solo 2's product.

M135 also carries a BMM150 magnetometer and a BMP280 barometer. They are on the board and out of the product. Closed decision: GNSS + 6-axis IMU only.

NEO-M9N dynamics limit is 4 g (also 80 km altitude, 500 m/s). Circuit riding is usually inside that. It is still an industrial module, not a race-rated logger.

## Language

Match the user (usually Spanish).
