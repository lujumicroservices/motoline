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

If STATUS and the user conflict, follow the user, then update STATUS.

## Pause

When the user says **pausa hardware**, ends the hardware thread, or a decision lands:

Update `hardware/STATUS.md` (date, what changed, next step, open questions). Update `BOM.md` / `DECISIONS.md` only if those actually changed.

Keep STATUS short.

## Honesty

Prototype is a **maker M5Stack stack** (Basic v2.7 on top of M135), not a sealed AiM dash. Do not generate polished commercial renders. Do not imply RTK or <0.5 m accuracy on the current BOM.

## Language

Match the user (usually Spanish).
