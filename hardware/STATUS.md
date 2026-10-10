# STATUS — hardware

> Archivo vivo. El agente lo actualiza al pausar o al cerrar una decisión.  
> Última actualización: 2026-10-10

## Fase

**Compra de 1 set de prototipo** (no el lote de 10). Diseño/BOM sigue siendo el de 10 unidades como referencia de costo.

## Chat de origen

[Hardware logger BOM](c349b6a7-8f93-4815-a7e1-a518e71cc66c) — 18 Sep 2026.

## Dónde nos quedamos

- BOM: **M135 + Basic v2.7 + Battery 13.2 (1500 mAh) + antena mag + buck + IP65 + ground plane**.
- Confirmado: M9N es L1 (no doble banda). F10 L1/L5 no vale la pena en circuito abierto; RTK queda como escalón posterior.
- Decisión de compra: **1 unidad** para primer prototipo, no 10.
- Power: Battery 13.2 **o** USB 5 V de moto **o** buck 12→5 V (no los tres a la vez).
- Cotización qty 1 en curso (M5Stack shop + SparkFun + local buck/caja).
- App (2026-10-10): emparejado BLE alineado con el firmware 0.6.8-ble ya flasheado. Servicio `6f8a0001-5c3e-4b8e-9a51-4d4554524943`, fragmentos `0x1E`, MTU 247, STATUS `msg`/`err`/`left`. El Wi-Fi se escribe antes del PAIR. El secreto no se muestra ni se escribe en logs. El `PAIR` por USB sigue en la misma pantalla. `claim_code` no está en este repo: la app reenvía `ingest_url` tal cual.

## Siguiente paso (cuando se retome)

1. Confirmar y pedir el carrito qty 1 (núcleo M5Stack: Basic + M135 + Battery 13.2).
2. Al recibir: firmware mínimo en Basic (GPS lock, speed, lean crudo, log microSD).
3. Confirmar en el despliegue de `pair-logger-device` que `ingest_url` es Azure `logger-ingest` (el firmware sube con `X-Logger-Key`). La función no está en `supabase/functions`.

## Preguntas abiertas

- ¿Pedir ya antena SparkFun + ground plate, o primero solo stack M5Stack con la antena de 1 m incluida?
- ¿Shipping a México vía M5Stack + SparkFun, o un solo reseller (DigiKey / Amazon)?
- ¿RTK más adelante para el mismo circuito, o primero validar M9N en pista?

## Fuera de alcance de este chat

Shop RawThrottle, landing RiderLab, Play Console, APK.
