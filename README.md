# RiderLab

Motorcycle riding companion: record your ride, draw the **pilot line**, scrub any moment, improve corners.

> Formerly branded CornerIQ — same app / package; product name is now **RiderLab**.

## MVP (this repo)

- Start / end ride with phone GPS
- Offline-first SQLite storage (survives disconnects & app restarts)
- Crash recovery for unfinished rides
- Post-ride map with speed-colored polyline (OpenStreetMap tiles)
- Local ride history
- Ride Lab: segment zoom, brakes, curvas, friends + same-area / route compare

## Run

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Install (friends)

See [INSTALL.md](INSTALL.md) for Android APK sideload steps.

**Google Play:** see **[docs/PLAY_STORE.md](docs/PLAY_STORE.md)** for signed App Bundle + Console checklist.

Cloud backend: **[docs/SUPABASE.md](docs/SUPABASE.md)** — Supabase project under luju.nieves (dashboard still named CornerIQ; app is RiderLab).
