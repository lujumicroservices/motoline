# Track compare — teléfono vs M5 logger (Fase 4)

Protocolo honesto (sin reclamar RTK / cm).

## Setup

1. Misma moto, misma antena logger al cielo; teléfono en mount habitual.
2. Arrancar **ambos** recorders antes de salir.
3. Una vuelta (o tramo ≥3 min) con cielo abierto.
4. Logger: Stop → Upload (o import SD). Teléfono: stop + sync.

## Métricas a anotar

| Métrica | Teléfono | Logger M5 |
|---------|----------|-----------|
| point_count | | |
| duración | | |
| distancia (km) | | |
| max speed | | |
| GNSS Hz medio (pts/duración) | | |
| gaps > 2 s | | |
| HDOP / accuracy medio | | |
| jitter lateral visual (mapa overlay) | | |

## En RiderLab

- Abrir ambos rides en Compare / mapa.
- Chip **Logger M5** debe aparecer en el ride del hardware (`source=m5_logger`).

## Criterio de “listo para más”

- Logger produce track continuo sin teleports >40 m.
- Upload o import crea ride visible en historial del mismo user.
- Diferencia de distancia vs teléfono < ~5% en el mismo tramo (orden de magnitud; GPS L1).
