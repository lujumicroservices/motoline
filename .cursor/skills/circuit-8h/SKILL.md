---
name: circuit-8h
description: >-
  Resume the Circuito 8 horas survey (route A/B passes, start/finish/checkpoints,
  GPS precision, cloud rows, 24 Sep 2026 tracks). Use when the user says
  /circuit-8h, circuito 8 horas, circuit_8h, circuit8h, recorrido tipo A,
  recorrido tipo B, mapeo del circuito, pasadas A/B, or asks to rebuild the
  circuit map from those GPS passes to compare rider lines.
---

# Circuito 8 horas

Survey lane inside the RiderLab app. Goal: record the physical circuit so a later map can compare rider lines. Calibration layers are not built yet.

## Resume (every turn about this circuit)

1. Read [CONTEXT.md](CONTEXT.md).
2. Read [DATA.md](DATA.md) before querying Supabase, opening tracks, or proposing a circuit geometry.
3. Code lives in `apps/mobile/lib/features/experimental/circuit_8h/`. Read the file you will change; do not re-derive the model from memory.
4. Continue from **Siguiente** in CONTEXT. Do not re-ask closed decisions.

If CONTEXT and the user conflict, follow the user, then update CONTEXT.

## Honesty

Phone fused GPS on this survey is about 3–5 m. The lab gate is ±4 m. Centimeters need an external receiver or RTK. Do not claim the 24 Sep tracks are a finished circuit centerline.

Route labels A and B are survey buckets. Their physical meaning (which layout, which direction) was not defined. Do not invent it.

## Language

Match the user (usually Spanish).
