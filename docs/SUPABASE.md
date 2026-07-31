# RiderLab cloud (Supabase)

App brand: **RiderLab**. Cloud project in dashboard is still named **CornerIQ** (same org **luju.nieves** — not Luju POS / auto).

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

Migrations:

- `supabase/migrations/20260730200000_corneriq_core.sql` — core tables + RLS
- `supabase/migrations/20260731010000_friends_bbox_compare.sql` — ride bbox + overlap RPC + closed-beta profile visibility

Tables: `profiles`, `routes`, `rides`, `track_points` with RLS:

- Own rows: full access
- Shared rides/routes: readable by other authenticated users (peer compare)
- **Closed beta:** every authenticated user can read every `profiles` row (friends = all riders)
- `rides` bbox columns (`min_lat` / `max_lat` / `min_lng` / `max_lng`) for same-area match
- RPC `rides_overlapping(...)` — peer shared rides whose bbox intersects yours (with pad)

## Auth

Enable **Anonymous** sign-ins in Dashboard → Authentication → Providers (required for Friends + ride sync on device).

Direct link (CornerIQ project):  
https://supabase.com/dashboard/project/eabhnmlfsfibgwkspqwa/auth/providers

Without Anonymous, the Amigos screen shows “nube no disponible” / a prompt to enable it.

Email / magic-link can be added later for named riders.

## CLI

```bash
# from repo root (already linked)
supabase link --project-ref eabhnmlfsfibgwkspqwa
supabase db query --linked -f supabase/migrations/20260730200000_corneriq_core.sql
supabase db query --linked -f supabase/migrations/20260731010000_friends_bbox_compare.sql
```

## Product steps

1. Enable **Anonymous** auth (required)
2. Upload ride after End ride (`is_shared` from toggle, bbox, optional `route_id`)
3. **Routes** screen: create named circuits, share toggle
4. Ride Lab: assign ride to route + share this ride
5. Friends list = all profiles (closed beta)
6. Compare: peers on same `route_id` **or** overlapping bbox
