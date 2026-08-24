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
- `supabase/migrations/20260824010000_pro_entitlements.sql` — Pro trial + partner codes (`promo_codes`, `entitlement_periods`)

Tables: `profiles`, `routes`, `rides`, `track_points` with RLS:

- Own rows: full access
- Shared rides/routes: readable by other authenticated users (peer compare)
- **Closed beta:** every authenticated user can read every `profiles` row (friends = all riders)
- `rides` bbox columns (`min_lat` / `max_lat` / `min_lng` / `max_lng`) for same-area match
- RPC `rides_overlapping(...)` — peer shared rides whose bbox intersects yours (with pad)
- `promo_codes` / `entitlement_periods` — Pro trial + partner grants (select own rows; writes via RPCs)

## Auth

RiderLab **requires a real account**. There is no guest / anonymous mode.

On launch, unsigned riders see a full-screen gate (Google or email/password). Turn **Anonymous** off in Dashboard → Authentication → Providers.

### Google Sign-In

The launch gate and Settings → **Account** offer **Sign in with Google**.

**Dashboard**

1. Authentication → Providers → **Google** → Enable  
2. Enable **Manual linking** only if you later add more providers to the same user  
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

Apple Sign-In still needs its own provider before App Store if Google stays on iOS. Email/password is live (see below).

### Email + password

Enable **Email** in Dashboard → Authentication → Providers.

Recommended for store review and riders who skip Google:

1. Email provider **on**
2. **Confirm email**: off for closed beta (or leave on and pre-create the review user as confirmed)
3. Email provider is enough for review accounts; Anonymous should stay **off**

**Create an App Store / Play review user** (do not commit the password):

1. Authentication → Users → **Add user**
2. Email like `review@riderlab.rawthrottle.com.mx`
3. Auto-confirm the user
4. Paste that email + password in Play Console **Sign in details** and App Store Connect **Demo account**

Riders: first screen is sign-in (Google or email). Settings → Account signs out back to that screen.

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
7. Entitlements: [FREE_VS_PRO.md](FREE_VS_PRO.md). Migration `supabase/migrations/20260824010000_pro_entitlements.sql` (`promo_codes`, `entitlement_periods`, trial/redeem RPCs).
