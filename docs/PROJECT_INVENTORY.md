# RiderLab — inventario del proyecto

Documento vivo para saber **qué existe, dónde vive, en qué estado está y qué no tocar a ciegas**.
No sustituye los runbooks (Play, Supabase, legal). Los enlaza.

| | |
|---|---|
| **Última revisión** | 2026-09-07 |
| **Producto** | RiderLab (RawThrottle) |
| **Repo** | `lujumicroservices/motoline` |
| **App en código** | `apps/mobile` — pub name `motoline`, UI **RiderLab** |
| **Package ID** | `com.rawthrottle.riderlab` (Android + iOS bundle) |
| **Versión en `pubspec.yaml`** | `1.37.13+88` |
| **En testers Play (alpha)** | `1.37.12` — el `1.37.13` estaba local y **no** se subió (family-watch recovery) |
| **Plataforma de shipping** | Android first. iOS existe en el árbol, **no** es canal de release. |

---

## Cómo mantener este inventario

Actualiza este archivo (fecha + fila afectada) cuando ocurra **cualquiera** de esto:

1. Nueva carpeta en `apps/mobile/lib/features/` o servicio en `core/services/`.
2. Nueva Edge Function, migración SQL, tabla o bucket.
3. Nuevo secreto / sistema externo (Azure, FCM, Places, Valhalla, RevenueCat).
4. Cambio de versión Play / `pubspec.yaml`.
5. Feature flag que se enciende o se apaga (`AppFeatures`, Free vs Pro).
6. Decisión de producto que deja código muerto (pausar rutas, IAP, iOS).

**Estados** (úsalos en las tablas; no inventes otros):

| Estado | Significado |
|---|---|
| `shipped` | En testers o sideload, UX visible |
| `gated` | Código vivo, cerrado por Pro / flag / canal |
| `experimental` | Lab / Settings, no es el camino feliz |
| `paused` | Cableado, UX oculta a propósito |
| `debt` | Legacy, nombre viejo, o riesgo conocido |
| `ops-only` | Scripts / infra, no app |

No copies contratos largos aquí. Enlaza:

| Tema | Doc |
|---|---|
| Gratis vs Pro | [FREE_VS_PRO.es.md](FREE_VS_PRO.es.md) · [FREE_VS_PRO.md](FREE_VS_PRO.md) |
| Requisitos vivos | [REQUIREMENTS.md](REQUIREMENTS.md) |
| Cloud | [SUPABASE.md](SUPABASE.md) |
| Play | [PLAY_STORE.md](PLAY_STORE.md) · [PLAY_PRODUCTION.md](PLAY_PRODUCTION.md) |
| Family Watch | [FAMILY_WATCH.md](FAMILY_WATCH.md) |
| Curvas / labels | [CURVE_TELEMETRY.md](CURVE_TELEMETRY.md) · [ENGINE_LABELS.md](ENGINE_LABELS.md) |
| Cámara | [ADVENTURE_CAMERA.md](ADVENTURE_CAMERA.md) |

---

## 1. Mapa del sistema

```text
Teléfono (Flutter, flavor play | sideload)
  ├─ SQLite motoline.db  (offline-first, WAL, v20)
  ├─ RideRecorder        GPS + IMU lean + baro + arm FGS
  ├─ SyncOutbox          → RideSyncService → Supabase
  └─ ImuBlobUpload       → Azure Function SAS → Blob lean-replay

Supabase  eabhnmlfsfibgwkspqwa  (us-west-1)
  ├─ Auth (Google + email; sin guest)
  ├─ Tablas + RLS (rides, rodadas, watch, Pro, FCM…)
  └─ Edge Functions (7)  FCM, Places, Valhalla, delete, impersonate

Azure
  ├─ riderlabdeck / $web     https://riderlab.rawthrottle.com.mx
  │                            /watch  /legal  /auth/reset-password
  └─ rg-riderlab  riderlabimu  SAS: riderlabimusas.azurewebsites.net

Play Console  closed testing = alpha track  package com.rawthrottle.riderlab
```

**Nombres históricos (no renombrar a ciegas):** pub `motoline`, DB `motoline.db`, prefs `corneriq_*`, migraciones `corneriq_core`. Producto y store: **RiderLab**.

---

## 2. Monorepo

| Path | Qué es | Estado |
|---|---|---|
| `apps/mobile/` | App Flutter | `shipped` |
| `packages/ride_core/` | GPS gaps, smoothness, modelo outbox (Dart puro) | `shipped` |
| `supabase/migrations/` | Schema + RLS | `shipped` |
| `supabase/functions/` | 7 Edge Functions | `shipped` |
| `supabase/scripts/` | Ops + **`_tmp_*` scratch** (no runbooks) | `ops-only` / `debt` |
| `infra/azure/lean-replay/` | Blob IMU + Function SAS | `shipped` |
| `docs/` | Arquitectura, store, legal, decks, watch | `shipped` |
| `docs/watch/` | Viewer Family Watch (estático) | `shipped` |
| `scripts/` | Deploy legal / watch / auth-reset → Azure `$web` | `ops-only` |
| `.github/workflows/` | `mobile-ci` + `play-release` | `shipped` |
| `.cursor/` · `.ironbee/` | MCP / skills / escenarios | `ops-only` |
| `apps/mobile/ios/` | Proyecto iOS | `paused` (no canal) |

---

## 3. App — módulos de producto

Entrada: `apps/mobile/lib/main.dart` → AuthGate → Home (garage).

### 3.1 Features (`lib/features/`)

| Módulo | Entrada principal | Hace | Estado |
|---|---|---|---|
| `auth` | `SignInScreen`, `AuthGate` | Google / email, recovery | `shipped` |
| `legal` | `TermsAcceptScreen` | Aceptación términos/privacidad | `shipped` |
| `home` | `HomeScreen` | Garage, armar/grabar, nav, recovery | `shipped` |
| `ride_active` | `ArmedSessionScreen`, `ActiveRideScreen` | Armar → HUD, tramos, loop marks | `shipped` |
| `ride_detail` | `RideDetailScreen`, Skill Lab, mapa | Post-ride lab, Pro gates | `shipped` / `gated` |
| `rodadas` | `RodadasScreen`, `RodadaDetailScreen` | Grupo, live, radio, fotos, itinerario | `shipped` |
| `friends` | `FriendsScreen` | Grafo social | `shipped` |
| `watch` | `FamilyCircleScreen` | Links live para familia (web `/watch`) | `shipped` |
| `reel` | `ReelComposeScreen` | Highlight video del ride | `shipped` |
| `compare` | ride / route compare | Peer o misma ruta | `shipped` / `paused` (ruta) |
| `settings` | `SettingsScreen` | Locale, moto, Pro, sync, Lab, staff | `shipped` |
| `lean_lab` | `LeanLabScreen` | Protocolo de calibración lean | `experimental` |
| `telemetry` | `RideEngineLabelScreen` | Labels para entrenar modelos | `experimental` |
| `adventure_camera` | Settings → Lab | GoPro BLE / zonas | `experimental` |
| `moderation` | report sheet, staff reports | UGC rodada | `shipped` |
| `maps` | mixins | Blue-dot live sin rebuild | `shipped` |
| `pro` | banners | Upsell | `gated` (IAP Play no live) |
| `routes` | `RoutesScreen` | Circuitos con nombre | `paused` (`AppFeatures.routesEnabled = false`) |

### 3.2 Servicios (`lib/core/services/`) — inventario de runtime

| Servicio | Responsabilidad | Notas |
|---|---|---|
| `RideRecorder` | Grabación GPS+IMU, arm auto-start, auto-pausa | Corazón offline |
| `LocationService` | Stream ~10 Hz pedido, filtro accuracy 40 m, teleport | `sampleInterval` 100 ms |
| `MotionPatternDetector` | Pausa 12 s &lt;8 km/h; resume 12 km/h / 15 m | Puro Dart, testeado |
| `ArmForegroundService` | Isolate FGS mientras armado (pantalla off) | Poll 1 Hz, timeLimit 8 s |
| `LeanSensor` / `LeanEngine` | Lean firmado, freeze g0 | Lab + ride |
| `BarometerSensor` | hPa opcional | |
| `SyncOutboxService` | Cola SQLite → `syncRide` | Kind `track_chunk` reservado, no usado |
| `RideSyncService` | Push/pull rides + puntos | Políticas fillGaps / richer |
| `ImuBlobUploadService` | Pack IMU → SAS Azure | |
| `LiveShareLoop` | Ping GPS rodada / family watch | Backoff + last-known (1.37.13) |
| `RouteService` / `RouteLoopService` | Circuitos y loops | UX pausada |
| `LoopSessionController` | Auto-lap en HUD | Loop mode shipped |
| `DirectionsService` | Edge `valhalla-route` | Rodada itinerario |
| `PlaceSearchService` | Edge `places-search` + Nominatim | |
| `AppUpdateService` | GitHub APK (solo sideload) | Play flavor quita el permiso |
| `RiderTelemetryService` | Eventos de diagnóstico → cloud | |
| `RidePlaceNameService` | Título start–end | |

### 3.3 Providers Riverpod (`lib/providers/`)

`auth`, `alias`, `bike`, `locale`, `pro_entitlement`, `ride`, `social`, `supabase`, `update`.

Feature-local: `rodada_providers`, `watch_providers`, `adventure_camera_providers`, moderation.

### 3.4 Flags y canales

| Flag / define | Valor actual | Efecto |
|---|---|---|
| `DISTRIBUTION` | `play` \| `sideload` (default sideload) | Updates APK, toggle Pro local |
| `AppFeatures.routesEnabled` | `false` | Oculta Rutas / assign-to-ruta |
| `REVENUECAT_API_KEY` | opcional | Sin key → no IAP; sideload puede toggle |
| l10n | `es` (template) + `en` | Default español |

---

## 4. Datos

### 4.1 SQLite local (`motoline.db`, version **20**)

`rides`, `track_points`, `lean_samples`, `imu_samples`, `sync_outbox`, `lean_lab_sessions`, `ride_engine_labels`, `camera_events`, `route_loops`, `routes`, `imu_uploads`, `ride_photos`.

Los **tramos / trayectos del hub armado no son tabla**. Se derivan de `track_points` con hueco de tiempo &gt; 8 s (`rideStretchesFrom` → `splitByGpsGaps`). Misma constante en `ride_core`, mapa y reel.

### 4.2 Supabase (tablas clave)

| Dominio | Tablas |
|---|---|
| Core | `profiles`, `routes`, `rides`, `track_points` |
| Rodada | `rodadas`, `rodada_members`, `rodada_live_positions`, `rodada_photos`, `rodada_messages`, `rodada_stops`, `rodada_reels` |
| Watch | `trusted_contacts`, `watch_sessions`, `watch_positions`, `watch_events`, `watch_share_tokens`, `watch_share_access` |
| Social | `friendships`, `user_bans`, `content_reports` |
| Pro | `promo_codes`, `entitlement_periods` |
| FCM | `device_tokens` |
| Staff | `staff_admins`, `impersonation_audit` |
| Telemetría | `camera_events`, `camera_config_snapshots`, `ride_engine_labels` |
| Storage | buckets `rodada-photos`, `rodada-reels` |

Migraciones: `supabase/migrations/` (23 a la fecha de esta revisión). **Nunca** editar una migración ya aplicada; añadir otra.

### 4.3 Edge Functions

| Función | Uso | Secretos (nombres) |
|---|---|---|
| `notify-rodada-invite` | Push invitación | `FIREBASE_SERVICE_ACCOUNT` |
| `notify-rodada-radio` | Push radio / alertas | idem |
| `notify-rodada-started` | Push “rodada en vivo” | idem |
| `places-search` | Google Places | `GOOGLE_PLACES_API_KEY` |
| `valhalla-route` | Ruta carretera | `VALHALLA_URL`, `VALHALLA_API_KEY` |
| `delete-account` | Borrado GDPR / Play | service role |
| `impersonate-user` | Staff magic link | `IMPERSONATE_ADMIN_IDS` / `staff_admins` |

---

## 5. Sistemas externos y secretos (solo nombres)

**App** (`apps/mobile/.env`, gitignored): `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` / `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `WATCH_SHARE_BASE_URL`, `REVENUECAT_API_KEY`, `AZURE_LEAN_SAS_URL`.

**GitHub Actions Play:** `PLAY_KEYSTORE_*`, `PLAY_KEY_ALIAS`, `MOBILE_ENV`, `GOOGLE_SERVICES_JSON`, `PLAY_SERVICE_ACCOUNT_JSON`.

**Azure está en dos resource groups** (fácil de confundir):

| RG | Para |
|---|---|
| `rg-nkmoto` | Static `$web` `riderlabdeck` (sitio público) |
| `rg-riderlab` | IMU storage `riderlabimu` + Function SAS |

Sitio público: `https://riderlab.rawthrottle.com.mx/` (`/watch`, `/legal/*`, `/auth/reset-password`).

---

## 6. Release y CI

| Pieza | Detalle |
|---|---|
| CI | `.github/workflows/mobile-ci.yml` — `ride_core` tests + Flutter analyze/test. Sin secretos. |
| Play | `play-release.yml` — `workflow_dispatch`, tracks `internal` \| `alpha` \| `beta`. Closed testing **es alpha**. No crear otra closed track. No pausar Alpha. |
| Flavors | `play` (default gradle) y `sideload`. Mismo `applicationId`. Play quita `REQUEST_INSTALL_PACKAGES`. |
| Build Play | `flutter build appbundle --flavor play --dart-define=DISTRIBUTION=play` |
| Sideload | APK + `DISTRIBUTION=sideload`; updates desde GitHub Releases |

Bump de versión: `apps/mobile/pubspec.yaml` + `play/whatsnew` + `releaseName` en el workflow.

---

## 7. Tests (cobertura de inventario, no de líneas)

~46 tests en `apps/mobile/test/` + `packages/ride_core/test`. **No hay** `integration_test/`.

Bien cubierto: motion pause, loops, curvas, lean math, reel pauses, Pro entitlement, rodada prefs/invite, live_share backoff, geo split.

Huecos relevantes: `RideRecorder._onPosition` (accuracy skip + teleport 45 s), grabación end-to-end, dual stream arm FGS + dense GPS, recovery de watch en el teléfono (el loop sí tiene unit test).

---

## 8. Deuda y riesgos conocidos (código)

Revisión 2026-09-07. Prioridad = impacto en rodada / datos / store.

### P1 — Grabación / tramos

**Corregido 2026-09-08** (en el árbol; testers lo ven en el próximo Play):

1. Hub tramos: `splitByStopGaps` (hueco ≥ 12 s **y** velocidad implícita &lt; ~8 km/h). Túnel / dropout en movimiento = mismo tramo. El mapa sigue usando `splitByGpsGaps` para el hueco visual.
2. Auto-pausa no reanuda por 15 m si el salto cabe en el círculo de accuracy.
3. `classifyGpsJump`: corte largo ancla de nuevo en vez de tirar el resto del ride. Clamp de teletransporte 180 s.

### P2 — Live share / Play

5. Recuperación Family Watch + rodada live tras pérdida de señal está en **1.37.13 local**. Testers siguen en 1.37.12 hasta que se pida push + `play-release` alpha.
6. Viewer web `/watch` ya reintenta red; el teléfono no, hasta ese build.

### P3 — Repo / ops

7. `supabase/scripts/_tmp_*` (SQL/JS con datos reales) **no son runbooks**. Varios untracked. No commitear.
8. Dual lógica de gaps: `packages/ride_core` y `apps/mobile/lib/core/utils/geo_utils.dart`.
9. Prefs `corneriq_*`, DB `motoline.db`, descripción pubspec `"A new Flutter project."`.
10. `routesEnabled = false` deja código de rutas/loops de ruta vivo y fácil de romper sin UX.
11. IAP Play no activo; Free vs Pro depende de trial / partner / toggle sideload. Banner ads es placeholder (no AdMob).
12. `_promoteArmedToRecording` no resetea contadores `_wasPaused` / skip GPS (el `start()` manual sí).

---

## 9. Recomendaciones

Ordenadas para mantener el inventario **y** el producto. No son un sprint impuesto; son la cola que el código pide.

### Inventario / higiene

- **Ignorar o borrar** `supabase/scripts/_tmp_*`. Si hace falta un script ops, nombrarlo sin `_tmp_` y documentarlo en [SUPABASE.md](SUPABASE.md).
- En cada bump Play, actualizar la tabla de versión **arriba** de este archivo (código vs testers).
- Una sola constante `gpsGapMax` (hoy 8 s) exportada desde `ride_core`; app y reel la importan.
- Documentar en este archivo cualquier Edge Function o secreto nuevo **el mismo PR**.

### Grabación

- Tramos / jitter / recovery de corte largo: hecho 2026-09-08. Falta el build Play para testers.

### Release

- Subir **1.37.13** a alpha cuando se quiera family-watch recovery en testers (mismo track; no crear closed track nueva).
- No omitir `--dart-define=DISTRIBUTION=play` en AAB (el default del código es sideload).

### Producto / código muerto

- Decidir rutas: reactivar con Pro **o** archivar el feature folder para no mantener dos mundos.
- iOS: o un hito “no shipping” explícito en [STORE_READINESS.md](STORE_READINESS.md), o no tocar el folder salvo que compile CI.
- Cuando IAP esté live, quitar el toggle Pro de sideload en builds que puedan filtrarse, o dejarlo solo en flavor debug.

---

## 10. Checklist al añadir algo

- [ ] ¿Feature nueva? Fila en §3.1 + estado.
- [ ] ¿Servicio nuevo? Fila en §3.2.
- [ ] ¿Tabla / RPC / función? §4 + enlace a migración.
- [ ] ¿Secreto? Nombre en §5, valor **nunca** aquí.
- [ ] ¿Cambia Free/Pro o un flag? §3.4 + doc de contrato.
- [ ] ¿Versión Play? Cabecera de este archivo + whatsnew.
- [ ] ¿Riesgo nuevo? §8 con prioridad.

Última revisión: **2026-09-07**.
