---
name: mx-pilot
description: Resume and continue the RiderLab motocross-pilot lane (técnica MX, circuito 8 Horas Zapopan, variantes de producto para dirt). Use when the user says /mx-pilot, retoma piloto, pausa piloto, 8 Horas, motocross, MX, dirt, bermas, whoops, saltos, o pide variantes de RiderLab para circuito de tierra.
---

# MX Pilot

Work lives in `mx-pilot/`. This is a **separate lane** from hardware, shop, landing, and Play.

You are not a licensed coach and you have not ridden 8 Horas. You apply **documented technique + notes from the user + telemetry**. Do not invent sectors, jump names, or a fake track map.

## Resume (every MX turn)

1. Read `mx-pilot/STATUS.md`.
2. Read `mx-pilot/CONTEXT.md` and `mx-pilot/CIRCUIT_8_HORAS.md`.
3. Read `mx-pilot/TECHNIQUE.md` and `mx-pilot/DECISIONS.md`.
4. Continue from **Siguiente paso** in STATUS. Do not re-ask closed decisions.

If STATUS and the user conflict, follow the user, then update STATUS.

## Pause

When the user says **pausa piloto**, ends the thread, or a decision lands:

Update `mx-pilot/STATUS.md` (date, what changed, next step, open questions). Update `CIRCUIT_8_HORAS.md` / `DECISIONS.md` / `TECHNIQUE.md` only if those actually changed.

Keep STATUS short.

## Honesty

- **8 Horas** is the circuit of record. Examples, tests, and product variants start there.
- Current capture is the **phone** (~1–5 Hz GNSS fused, IMU lean). Do not design MX features as if we already had 10–25 Hz hardware.
- Street / asphalt models in RiderLab (Bugambilias Lean Lab, auto-pause, curve taxonomy, speed colors) **do not transfer** to dirt without an explicit product decision.
- No medical, race-license, or “haz este salto” prescriptions. Technique is framed as options the rider confirms on the section they know.

## Language

Match the user (usually Spanish). Use the rider’s names for sectors once they exist in `CIRCUIT_8_HORAS.md`.
