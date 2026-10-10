# STATUS — hardware

> Archivo vivo. El agente lo actualiza al pausar o al cerrar una decisión.  
> Última actualización: 2026-10-01

## Fase

**Dos BOM.** **Pro** = partes sueltas + RTK ([BOM-pro.md](BOM-pro.md)). **Standard** = stack M5/M9N ([BOM-standard.md](BOM-standard.md)), sin compra hasta decidir.

## Chat de origen

[Hardware logger BOM](c349b6a7-8f93-4815-a7e1-a518e71cc66c) — 18 Sep 2026.  
BOM Pro abierto el 1 oct 2026 (partes sueltas, doble banda, RTK). Nombres Pro / Standard fijados el mismo día.

## Dónde nos quedamos

- El usuario pidió un BOM **low-level** (piezas sueltas, no stack M5) con **GNSS doble banda y RTK**.
- Elegido para ese BOM: **ZED-F9P L1/L2** + antena ANN-MB-00 + ESP32-S3 + BMI270 + pantalla 2" ST7789 + LoRa 915 MHz, y **una base** igual en el paddock.
- Precisión: centímetros solo en **RTK fixed**. Sin base, ~1.5 m. En moto, unos cm a ~10–20 cm, no 1 cm de banco.
- Tasa realista: ~10 Hz (GPS+GAL), no 20 Hz con las cuatro constelaciones.
- Costo de lista: ~$495/rover + ~$443 la base. Proto 1+1 ≈ $940.
- La compra M5 de 1 set **no se hizo** y queda en pausa.

## Siguiente paso (cuando se retome)

1. Revisar [BOM-pro.md](BOM-pro.md) y confirmar el carrito **1 rover + 1 base** (no el lote de 10).
2. Al recibir: firmware mínimo (UBX + tipo de fix, RTCM por LoRa, lean BMI270, log microSD).
3. Una sesión en el circuito: ¿el LoRa aguanta la vuelta entera en FIXED?

## Preguntas abiertas

- ¿El 915 MHz cubre este circuito desde paddock, o hay que pasar a NTRIP?
- ¿La pantalla de $20 se lee al sol, o hace falta visera / panel más brillante?
- ¿Se archiva la compra del BOM Standard o se deja como plan B?

## Fuera de alcance de este chat

Shop RawThrottle, landing RiderLab, Play Console, APK.
