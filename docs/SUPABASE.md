# RiderLab cloud (Supabase)

App brand: **RiderLab** (org **luju.nieves** — not Luju POS / auto).

| | |
|---|---|
| Project | **RiderLab** |
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

### Anonymous (guest)

Enable **Anonymous** sign-ins in Dashboard → Authentication → Providers (still used for first-run guest + Friends / ride sync before Google).

Direct link (RiderLab project):  
https://supabase.com/dashboard/project/eabhnmlfsfibgwkspqwa/auth/providers

Without Anonymous, the Amigos screen shows “nube no disponible” / a prompt to enable it.

### Google Sign-In

Settings → **Account** offers **Sign in with Google**. Anonymous guests are **linked** to Google when possible (`linkIdentityWithIdToken`) so the same `auth.users` / ride IDs are kept.

**Dashboard**

1. Authentication → Providers → **Google** → Enable  
2. Enable **Manual linking** (Authentication → Providers / Auth settings) so anonymous → Google works  
3. Paste Google **Web client ID** + **Client secret** (and list Android/iOS client IDs if prompted)

**Google Cloud Console**

1. Create a project (or reuse one) → [Clients](https://console.cloud.google.com/auth/clients)  
2. **Web application** OAuth client — copy Client ID → `GOOGLE_WEB_CLIENT_ID` in `apps/mobile/.env`  
3. **Android** OAuth client — package `com.rawthrottle.riderlab` + SHA-1 of your debug/release keystore  
4. **iOS** OAuth client (when shipping iOS) — bundle id + `GOOGLE_IOS_CLIENT_ID` + `CFBundleURLTypes` reversed client id in `Info.plist`

**App `.env`**

```env
GOOGLE_WEB_CLIENT_ID=….apps.googleusercontent.com
# GOOGLE_IOS_CLIENT_ID=….apps.googleusercontent.com
```

Get Android debug SHA-1:

```bash
cd apps/mobile/android
./gradlew signingReport
```

### Future providers

Auth is routed through `AuthProviderKind` + `AuthService.signInWith(...)` (`lib/core/auth/`). Add Apple / email as new enum cases and handlers; Settings already loops `availableProviders`.

Email / magic-link can be added the same way for named riders.

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
