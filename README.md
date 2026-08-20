# RiderLab

Motorcycle riding companion: record your ride, draw the **pilot line**, scrub any moment, improve corners.

> Product name is **RiderLab** by RawThrottle.

## Monorepo

```text
apps/mobile/          # Flutter app (Android first)
packages/ride_core/   # Pure Dart: GPS gaps, smoothness, sync outbox models
supabase/             # Migrations + scripts
docs/                 # Architecture, store, partner decks, legal
```

## MVP (this repo)

- Start / end ride with phone GPS + IMU lean (+ baro when available)
- Offline-first SQLite with **WAL** batches and crash recovery
- Durable **sync outbox** + Supabase cloud garage
- Post-ride map (OpenStreetMap / flutter_map): speed-colored line, GPS gap markers, scrub
- On-device insights: corners, brakes, skill coach cards
- Friends / rodadas; Lean Lab pilots
- Free / Pro gates (RevenueCat when `REVENUECAT_API_KEY` is set; local toggle otherwise)

## Run

```bash
cd packages/ride_core && dart pub get && dart test
cd ../../apps/mobile
cp .env.example .env   # fill Supabase + optional RevenueCat
flutter pub get
flutter gen-l10n
flutter run --flavor sideload --dart-define=DISTRIBUTION=sideload
```

## Install (friends)

See [INSTALL.md](INSTALL.md) for Android APK sideload steps.

**Google Play:** [docs/PLAY_STORE.md](docs/PLAY_STORE.md)  
**Store checklist + legal:** [docs/STORE_READINESS.md](docs/STORE_READINESS.md) · [docs/legal/](docs/legal/)  
**Cloud:** [docs/SUPABASE.md](docs/SUPABASE.md)
