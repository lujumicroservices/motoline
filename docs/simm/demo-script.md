# Demo 60–90 s (stand)

**Superficies que sí funcionan:** garaje (mapa) → Ride Lab (línea / curvas) → inclinación.  
**Saltar:** radio, rodada en vivo, “busca en Play”, Wi‑Fi de la expo.

## Antes de abrir

1. Dos teléfonos firmados, batería > 60 %, datos del hotspot (no expo Wi‑Fi).
2. Un ride **autorizado** en el garaje (script `copy_authorized_ride_to_demo.sql`).
3. Ubicación **Siempre**; RiderLab ya abrió una vez (permisos hechos).

## Guion (~90 s)

| t | Qué | Qué dices |
|---|---|---|
| 0–15 s | Garaje, tap del ride | “Esto es la línea que sí tomaste. El teléfono va en el bolsillo.” |
| 15–50 s | Ride Lab, scrub + una curva | “Entrada, ápice, salida. No es un velocímetro para mirar en marcha.” |
| 50–75 s | Inclinación L/R | “El IMU estima el lean junto a la traza. Se mira cuando ya te detuviste.” |
| 75–90 s | QR `/simm` | “Android 24 sep. Déjanos correo o WhatsApp. Al activar cuenta: 3 meses de Ride Lab (Pro). Grabar y el mapa siguen gratis.” |

Si el ride no carga: fotos de `docs/store/play/phone-0*.png` en el teléfono de apoyo. Video opcional: `apps/mobile/tool/demo/record-demo.ps1` clips `01-home`, `02-ride-summary`, `03-full-map`, `08-lean-lab`.
