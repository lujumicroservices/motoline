# Técnica MX ↔ lo que RiderLab puede ver

Modelo corto para diseñar producto. No es un manual de escuela. Si el piloto corrige una fila, se actualiza esta tabla.

## En qué piensa un piloto (y qué sensor lo toca)

| El piloto | Señal hoy (teléfono) | Señal si hay logger 10–25 Hz | Evento de app que tendría sentido |
|-----------|----------------------|------------------------------|-----------------------------------|
| Ritmo / no romper el flow | velocidad + huecos de tiempo | misma, más densa | tramo “rhythm”, no “recta” |
| Línea (adentro / berma / afuera) | trazada GPS (gruesa, 1–5 Hz) | trazada usable en ápice | variantes de línea en el mismo sector |
| Berma vs plano vs off-camber | heading + lean; camber no se ve | igual + menos jitter | tipo de curva **dirt**, no sweep/hairpin |
| Rodera que te encajona | línea repetible entre vueltas | más claro | “línea locked” vs exploración |
| Aproximación a salto | frenada + subida de speed | perfil de speed denso | fase *approach* |
| Lip / despegue | a veces un hueco GPS | pitch IMU + corte de GNSS | fase *lip* |
| Aire | hueco o teleport | airtime (pitch + pérdida de path) | fase *air* — **no** filtrar como basura |
| Aterrizaje | spike de accel / rebound | mismo, más limpio | fase *land* |
| Whoops | oscilación de pitch/accel | contable | evento *whoops*, no N curvas |
| Body position | el lean del bolsillo miente | IMU en chasis ayuda | Lean Lab MX ≠ protocolo Bugambilias |
| Holeshot / salida | primer tramo de la manga | igual | marca de gate, no “inicio de calle” |

## Reglas para no mezclar asfalto

1. **Auto-pausa:** en MX, lento ≠ parado. No proponer el umbral de calle sin un modo circuito.
2. **Teleport GPS:** un salto puede parecer un salto de puntos. Antes de tirar el sample, preguntar si hubo aire.
3. **Lean:** en tierra el ángulo de chasis y el del cuerpo no coinciden; el teléfono en el bolsillo es peor que en calle. No vender “máxima inclinación” como skill de MX.
4. **Taxonomía de curvas:** no forzar sweep / hairpin / chicane sobre bermas y whoops.
5. **Velocidad de calle:** no reusar rampas 65/90/130 km/h como verdad de pista.
6. **Vueltas:** el layout cambia con roderas y con cómo armó la pista el day-of. La identidad de “misma ruta” es más floja que en Bugambilias.

## Variantes de línea (producto)

En un mismo sector de 8 Horas pueden coexistir 2–3 líneas. RiderLab hoy compara vueltas enteras. La variante MX útil es:

- misma manga, **mismo sector**, dos pasadas
- etiqueta que pone el piloto (`berma` / `adentro` / `fuera`)
- delta de tiempo **del sector**, no solo de la vuelta

Hasta que existan sectores nombrados, no implementar esto.

## Seguridad (tono)

Hablar de opciones (“la berma perdona más si el lip está roto”), no de órdenes. Si no hay nota del piloto sobre ese sector, no recomendar un salto concreto.
