# Precisión de inclinación — protocolo de validación con 3 teléfonos

Ejecuta esto **antes** de subir la versión en `apps/mobile/pubspec.yaml` para un release de lean.

Metas de éxito (del plan avanzado de lean):

1. Pared / clinómetro, cualquier pose: `|vector − clinómetro| ≤ ~3°`
2. Montaje rígido en tanque, curva constante, `v > 40 km/h`: mediana `|IMU − GPS kin| ≤ ~8°`
3. Bolsillo A/B (doble): banners de pose correctos; la confianza baja cuando L/R divergen (**no** exigir igualdad absoluta en grados)

## A. Inclinación contra pared (3 teléfonos)

1. Abre **IMU Lean Lab** en cada teléfono.
2. Congela vertical (sostén 4 s) con el teléfono en la pose a probar:
   - Vertical portrait (tanque)
   - Plano, pantalla hacia arriba
   - Landscape de costado
3. Inclina contra una pared hasta un ángulo conocido del clinómetro (~27°).
4. Anota: lean vector, lean de moto, banner de pose, lectura del clinómetro.
5. Pasa si el **vector** de los tres teléfonos está a ~3° del clinómetro.

## B. Rodada con montaje en tanque

1. Monta el teléfono de forma rígida en el tanque (portrait o plano — congela en esa pose).
2. Rodada una curva de radio constante / rotonda por encima de 40 km/h.
3. En IMU lab / Ride Lab, compara lean IMU vs lean GPS en el banner (o en `lean_samples`).
4. Pasa si la mediana del desacuerdo absoluto ≤ ~8° en ese tramo.

## C. Bolsillo A/B (mismo rider, dos teléfonos)

1. Bolsillo izquierdo + bolsillo derecho, misma moto, misma vuelta (estilo Bugambilias).
2. Usa el freeze **Guardar en el bolsillo** (nunca congelar en la mano).
3. Pasa si:
   - Clase de pose = Vertical
   - Confianza de lean más baja cuando los picos L/R son muy asimétricos
   - El lean máximo absoluto aún puede diferir — es esperado; no “arreglar” con un factor de escala global

## Puerta de ship

- [ ] A pasa en 3 teléfonos × vertical + plano
- [ ] B pasa en al menos una sesión con montaje en tanque
- [ ] C pasa (comportamiento de pose + confianza)
- [ ] Unit tests en verde (`lean_imu_math`, `lean_neutral`)
- [ ] Entonces subir versión y publicar

Hasta entonces mantén `1.29.x` (o la actual) — el código está listo; la validación es empírica.
