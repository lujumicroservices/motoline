# CornerIQ Supabase

Separate project under org **luju.nieves** (not Luju POS / auto).

| | |
|---|---|
| Project | **CornerIQ** |
| Ref | `eabhnmlfsfibgwkspqwa` |
| URL | https://eabhnmlfsfibgwkspqwa.supabase.co |
| Dashboard | https://supabase.com/dashboard/project/eabhnmlfsfibgwkspqwa |
| Region | `us-west-1` |

## Local app config

1. Copy `apps/mobile/.env.example` → `apps/mobile/.env`
2. Fill `SUPABASE_URL` + `SUPABASE_ANON_KEY` (anon / publishable only — never service_role in the app)
3. `flutter pub get && flutter run`

`.env` is gitignored.

## Schema

Migration: `supabase/migrations/20260730200000_corneriq_core.sql`

Tables: `profiles`, `routes`, `rides`, `track_points` with RLS:

- Own rows: full access
- Shared rides/routes: readable by other authenticated users (peer compare)

## Auth

Enable **Anonymous** sign-ins in Dashboard → Authentication → Providers (needed for device sessions without email yet).

Email / magic-link can be added later for named riders.

## CLI

```bash
# from repo root (already linked)
supabase link --project-ref eabhnmlfsfibgwkspqwa
supabase db query --linked -f supabase/migrations/20260730200000_corneriq_core.sql
```

## Next product steps

1. Upload ride after End ride (local SQLite → `rides` + `track_points`)
2. Tag `route_id` / loop mode
3. Compare UI: own + `is_shared` peers on same route
