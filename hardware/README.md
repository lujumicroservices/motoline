# Hardware — subproyecto RiderLab

Contexto persistente para diseñar y prototipar el logger (GNSS + IMU) que reemplaza al teléfono en pista.

## Cómo pausar y retomar

1. En **cualquier chat nuevo**, escribe `/hardware` o “retoma hardware”.
2. El agente lee `STATUS.md` (estado vivo) y luego `CONTEXT.md`, `BOM-standard.md` y `BOM-pro.md`.
3. Para **pausar**, di “pausa hardware”: se actualiza `STATUS.md` con lo último y el siguiente paso.

No hace falta reabrir el chat viejo. El chat de origen está citado en `STATUS.md`.

| Archivo | Qué es |
|---------|--------|
| [STATUS.md](STATUS.md) | Estado actual, siguiente paso, preguntas abiertas |
| [CONTEXT.md](CONTEXT.md) | Tesis del producto, métricas, restricciones |
| [BOM-standard.md](BOM-standard.md) | BOM Standard — stack M5 / M9N, sin RTK |
| [BOM-pro.md](BOM-pro.md) | BOM Pro — partes sueltas, L1/L2 + RTK |
| [DECISIONS.md](DECISIONS.md) | Decisiones ya cerradas (no reabrir sin pedirlo) |
