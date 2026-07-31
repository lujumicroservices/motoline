# CornerIQ

Motorcycle riding companion: record your ride, draw the **pilot line**, scrub any moment, improve corners.

## MVP (this repo)

- Start / end ride with phone GPS
- Offline-first SQLite storage (survives disconnects & app restarts)
- Crash recovery for unfinished rides
- Post-ride map with speed-colored polyline (OpenStreetMap tiles)
- Local ride history

## Run

```bash
cd apps/mobile
flutter pub get
flutter run
```

Use a **real device** outdoors for GPS. Emulators often give poor or static locations.

## Project layout

```
apps/mobile/lib/
  core/           # models, SQLite, GPS recorder
  features/       # home, active ride, pilot-line detail
  providers/      # Riverpod
  theme/
```

## Product requirements (next features)

See **[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)** for planned work:

- Unified **speed color** scale (high-contrast blue→magenta by speed) on map + charts
- Fixed **lean L/R** colors (cyan / amber)
- **Brake inference** from GPS speed drop (light / medium / hard)
- **Loop mode** (init + end, then auto lap recording)
- **Compare** metrics across rides on the same route (local → multi-user)
- **Segment zoom** — select a stretch of road and see metrics for that piece only

Cloud backend: **[docs/SUPABASE.md](docs/SUPABASE.md)** — separate **CornerIQ** project under luju.nieves (not POS).

## Next (from architecture plan)

- Mapbox upgrade for polished tiles / offline maps
- Technique insights (corners, smoothness)
- Supabase sync + RevenueCat freemium
- Store listing / background location justification
