# STATUS — hardware

> Archivo vivo. El agente lo actualiza al pausar o al cerrar una decisión.  
> Última actualización: 2026-09-26

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
- Comparado con **AiM Solo 2** (no el DL): misma clase de sensor (4 constelaciones L1, hasta 25 Hz, IMU 6 ejes, display). Solo 2 es el producto terminado (claim bajo 0.5 m, IP67, base de circuitos, delta). Prototipo: partes ~$128, línea esperada 1–2.5 m hasta medir en pista. Firmware aún no existe.

## Siguiente paso (cuando se retome)

1. Confirmar y pedir el carrito qty 1 (núcleo M5Stack: Basic + M135 + Battery 13.2).
2. Al recibir: firmware mínimo en Basic (GPS lock, speed, lean crudo, log microSD).
3. Definir entrada al stack RiderLab (archivo / BLE) después.

## Preguntas abiertas

- ¿Pedir ya antena SparkFun + ground plate, o primero solo stack M5Stack con la antena de 1 m incluida?
- ¿Shipping a México vía M5Stack + SparkFun, o un solo reseller (DigiKey / Amazon)?
- ¿RTK más adelante para el mismo circuito, o primero validar M9N en pista?

## Fuera de alcance de este chat

Shop RawThrottle, landing RiderLab, Play Console, APK.
