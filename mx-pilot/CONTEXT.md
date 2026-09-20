# Contexto — piloto MX para RiderLab

## Qué es esto

Lane **aparte** de hardware, shop y Play. Objetivo: que el agente piense como piloto de motocross en **un circuito real**, y desde ahí proponga variantes de RiderLab (eventos, labs, coaching, vueltas) que el asfalto no cubre.

No sustituye al piloto. No es un curso genérico de MX. Es una **memoria de pista + técnica + producto**.

## Cómo convertirme en un buen copiloto (no en un piloto)

Un skill no me hace rodar. Me hace **consistente**. El “mejor piloto” aquí significa: no mezclar asfalto con tierra, no inventar 8 Horas, y traducir lo que tú sientes a lo que la app puede medir.

Se construye en este orden:

1. **Un circuito de record** — 8 Horas. Todos los ejemplos empiezan ahí.
2. **Tus nombres** — tú caminas o ruedas y dictas: “la berma grande”, “el doble de la recta”, “whoops de la sombra”. Eso vive en `CIRCUIT_8_HORAS.md`. Sin nombre = no existe para el agente.
3. **Una trazada GPS** — primera vuelta (aunque sea a pie o en moto de baja) para bbox, sentido y A/B de meta. El teléfono da ~1–5 Hz; sirve para el mapa, no para ápices de salto.
4. **Fotos o un croquis** — lip, berma, whoops. Una foto vale más que un layout inventado.
5. **Después de cada sesión** — qué se sintió rápido, dónde te salvaste, qué línea usaste. Se anota en STATUS / circuito. Eso es el “entrenamiento”.
6. **Métrica ↔ sensación** — cada sector se mapea a un evento que RiderLab podría detectar (ver `TECHNIQUE.md`). Si no se puede medir con el teléfono, se marca como *necesita logger* o *nota manual*.

Pistas que me hacen peor, no mejor:

- Pedirme “el layout oficial” sin GPS ni tus nombres.
- Tratar Bugambilias / Lean Lab asfalto como si fuera MX.
- Diseñar features que asumen 25 Hz o RTK cuando seguimos en el celular.

## Relación con RiderLab (variantes, no código todavía)

Hoy la app está sesgada a **calle / asfalto**:

| Lo que existe | Por qué falla en MX |
|---------------|---------------------|
| Recta / curva (sweep, horquilla, chicane…) | En tierra el evento es berma, plano, off-camber, rodera |
| Lean Lab Bugambilias (`v > 40`, radio constante) | MX es más pitch, golpes, aire; poca curva “limpia” |
| Auto-pausa por baja velocidad | Secciones técnicas a 5–15 km/h no son un alto |
| Filtro de “teleport” GPS | Un salto se ve como hueco o salto de puntos |
| Colores de velocidad de calle (~65/90/130) | Techos distintos; una MX1 no se lee igual |
| Skill Lab de curva E/A/S | En salto el equivalente es aproximación / lip / aire / aterrizaje |

Variantes de producto que esta lane puede priorizar (cuando toque implementar):

- **Modo superficie:** calle vs MX (misma grabación, otro motor de eventos).
- **Eventos dirt:** salto, berma, whoops/rhythm, no solo recta/curva.
- **Vueltas** que sobrevivan huecos de aire y GPS flojo.
- **Variantes de línea** en el mismo sector (rodera adentro vs berma vs afuera).
- **Notas de coach** (ya son Pro en el contrato) ancladas a un sector de 8 Horas.
- **Marcas A/B + distancias** (trilateración) cuando el GPS no fije un lip o una meta.

## Relación con hardware

El logger M5Stack (10–25 Hz) es **otro lane**. Aquí se diseña pensando en el teléfono primero. Si una idea MX *solo* funciona con el logger, se etiqueta así; no se mezcla el BOM.

## Usuario y escenario

Piloto que ya usa RiderLab y va a **probar y rodar en 8 Horas**. Quiere que el agente hable el idioma de esa pista y que las ideas de app se puedan validar ahí el fin de semana, no en un circuito genérico.
