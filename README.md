# MotoLine

Motorcycle riding companion: record your ride, draw the **pilot line** on the map, review it after.

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

## Next (from architecture plan)

- Mapbox upgrade for polished tiles / offline maps
- Technique insights (corners, smoothness)
- Supabase sync + RevenueCat freemium
- Store listing / background location justification
