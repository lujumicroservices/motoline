# SIMM 2026 — stand pack

Expo Santa Fe, 17–20 Sep 2026. QR permanente: `https://riderlab.rawthrottle.com.mx/simm`

Play production **no** se promete en el stand. Android público previsto **24 sep 12:00 México**. iOS: solo lista de espera.

## Gap matrix

| Hueco | Estado | Criterio |
|---|---|---|
| URL + QR de evento | `/simm` + `site/qr-simm.png` | Un QR impreso sigue válido después del 24 sep |
| Pending vs Available | `store.json` (`androidReleaseAt`, `earlyAccessUrl`, `playUrl`) | Pending = formulario. Available = enlace Play/prueba + 3 pasos. Sin reimprimir |
| Leads | `event_leads` + función `submit-event-lead` | Nombre, Android/iPhone, correo **o** WhatsApp, consentimiento, `source=simm-2026` |
| 3 meses Pro | Códigos `SIMM26-…` (90 días) | Reservados en el lead; **no se envían** hasta que digas send |
| Early access | Solo si `earlyAccessUrl` está seteada y es real | No se afirma “ya está en Play” en el cartel |
| Demo 60–90s | [demo-script.md](demo-script.md) | 2 teléfonos con un ride autorizado; no radio/rodada en Wi‑Fi de expo |
| First-use | [staff-card.md](staff-card.md) | Always + freeze + **Start ride now** |
| Medición | hits `/simm` + filas `event_leads` | Un clic no es un install |
| Campañas | [follow-up.md](follow-up.md) **OFF** | Borradores; no se mandan solos |

## Copy (revisar, no auto-post)

- [signage.md](signage.md) — cartel + una línea
- [demo-script.md](demo-script.md) — 90 s
- [staff-card.md](staff-card.md) — first-use en el stand
- [faq.md](faq.md)
- [follow-up.md](follow-up.md) — WhatsApp/email **deshabilitados**
- [outreach.md](outreach.md) — grupos/escuelas, no enviado

## Ops

Mint códigos: `supabase/scripts/mint_simm26_codes.sql`  
Export leads: `supabase/scripts/export_simm_leads.sql`  
Ride de demo: `supabase/scripts/copy_authorized_ride_to_demo.sql` (tú eliges el ride)

## Play check (18 Sep 2026)

| Track | Hallazgo |
|---|---|
| Production listing | `play.google.com/store/apps/details?id=com.rawthrottle.riderlab` → **404** |
| Open testing URL | pide login de Google; **no** se trata como pública en `/simm` |
| AAB en API | 1.37.24+99 subido a production / beta / alpha; UI puede seguir En revisión |

`store.json.earlyAccessUrl` está **vacío** hasta que la prueba abierta instale de verdad. `/simm` queda en formulario.

- Autorizar qué ride va a los teléfonos de demo
- Cargar baterías + USB-C + hotspot celular
- Imprimir el QR **después** de abrir `/simm` en datos móviles
- Aprobar el primer blast (después del show / cuando la prueba abierta sea real)
