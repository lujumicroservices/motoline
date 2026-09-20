# Decisiones cerradas

No reabrir estas en un chat nuevo salvo que el usuario lo pida.

1. **Menos que el teléfono.** Hardware = GNSS + IMU 6 ejes + MCU + storage/display/BLE. Sin mag, sin barómetro como requisito.
2. **Trazada es métrica #1** para este dispositivo (pilotos pro, circuito).
3. **BOM actual = M9N + antena buena**, no RTK. Precisión esperada ~**1–2.5 m**, **10–25 Hz**, cerca / un poco peor que AiM.
4. **Lote de diseño: 10 unidades.**
5. **Display sí** (pedido del partner). Se reemplazó StampS3A + microSD suelta por **M5Stack Basic v2.7** (MCU + IPS 2.0" 853 nit + slot SD).
6. **Competidor principal de hardware: AiM Solo 2 / Solo 2 DL**, no el celular.
7. **Renders honestos:** stack M5Stack real, no dash comercial. Las primeras imágenes se sobre-diseñaron y se corrigieron.
8. Sourcing: se cotizó USA (M5Stack / SparkFun) y se pidió China; el BOM vivo sigue con SKUs M5Stack porque son los que apilan. China es para bajar BOM en una siguiente pasada, no para cambiar chips a ciegas.

## Escalones explícitamente *no* elegidos (aún)

- RTK F9P + base en paddock (mejor línea, más costo/ops).
- Solo logger sin pantalla.
- Replicar ECU/CAN de AiM DL.
