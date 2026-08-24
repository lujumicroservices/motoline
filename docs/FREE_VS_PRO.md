# RiderLab — Free vs Pro

Product contract. Recording and social stay free. Ride Lab depth is Pro. Every rider gets a 1-month full-Pro trial. Partners get 3 months via a single-use invitation code.

Resumen en español (Gratis, Pro, prueba, socio): **[FREE_VS_PRO.es.md](FREE_VS_PRO.es.md)**.

Paid store checkout is **not live** until Play IAP / RevenueCat offerings are enabled. The matrix below is still the contract: gates, trial, and partner grants follow these rules even while sideload uses a local Pro toggle.

Related: [STORE_READINESS.md](STORE_READINESS.md) (RevenueCat), [PLAY_PRODUCTION.md](PLAY_PRODUCTION.md) (no IAP on the current Play path), partner decks in [partner-deck/](partner-deck/).

## Principles

1. **Never lock recording or the garage.** The hook is “I rode, I have a line.” Ride-count caps train people to stop opening the app.
2. **Never lock social.** Friends, rodadas, live pack map, radio, photos, reels, and basic Family Watch are how the app spreads. Live safety share is not a paid extra in v1.
3. **Sell coaching depth, not the map.** Willingness to pay is “show me this corner / this brake / this stretch vs last weekend.”
4. **Trial covers real riding.** This is a weekend hobby. A 7-day clock from signup fails. **30 days of full Pro starting at the first completed ride.**
5. **Do not sell “no ads” until ads exist.** The Free banner is a placeholder, not AdMob. It is not a Pro benefit.
6. **Keep all recorded data after expiry.** Pro expires; rides and cloud copies stay. Analysis returns to Free depth.

## Always Free

Forever, including after trial or partner grant expiry:

- Sign-in, profile, bike picker
- Start / arm / auto-pause / crash recovery / unlimited local rides
- Cloud sync of rides you recorded
- Ride overview: distance, time, max speed, max lean L/R, skill score
- Pilot-line map, speed colors, scrub, charts, gauge
- GPS quality chip and GPS precision stats (trust in the line)
- Straights / corners **list** (tap a curva → short teaser, then lock)
- Skill Lab overview + replay of the **highlighted** corner
- First **3** brake events
- Friends, peer bbox compare (your ride vs a friend’s shared ride)
- Rodadas: create/join by **ride** invite code (e.g. `TAP42A`), live map, radio, photos, reels
- Family Watch: circle + live share link
- ES/EN

Rodada invite codes are **group-ride join**. They are not Pro grants.

## Pro

Active when any entitlement period is live (trial, partner, or paid). Same Ride Lab gates:

| Feature | Status | Why |
|---|---|---|
| Segment zoom / pick stretch | **Pro** | Highest-intent power feature |
| Full brake list + zoom-to-brake | **Pro** (Free sees first 3) | Clear teaser → upgrade |
| Full corner detail (entry/apex/exit) | **Pro** + teaser | Natural next tap after a good ride |
| GPS quality chip / precision stats | **Free** | Trust in the line, not a paid extra |
| Riding / coach notes (when present) | **Pro** | Coaching, not telemetry hygiene |
| “No ads” | **Not a Pro benefit** until AdMob is real | Placeholder banner must not be sold as value |
| Named routes + loop auto-lap | **Pro when unpaused** | Track-day value; do not give it away Free |
| Deep compare (vs own best / same named route overlay) | **Pro when routes return** | Bbox friend compare stays Free |
| GoPro shutter | **Lab** until reliable, then Pro | Hardware users pay; flaky labs are not a paid SKU |
| Family Watch history / extra contacts | **Later Pro**, not v1 | Do not paywall live safety now |
| Cloud history cap | **Not in v1** | Optional later (e.g. Free cloud = last 90 days; local unlimited). No ride-count cap. |

## Trial — 1 month of full Pro

No payment method. Full Pro for 30 days, then drop to Free. Store intro-offers (card on file, month 0 then charge) are a **later** path once Play IAP is live — not this trial.

**Clock**

- Starts on **first completed ride** (not install, not sign-in).
- If they never ride, they never burn the trial.
- Hard cap: trial must start within **90 days of account creation** so abandoned accounts do not sit on an infinite pending trial.
- One trial per account. Restore / new phone does not reset it (server-backed).
- During trial: quiet badge “Pro trial · N days left”. Hard paywall only after expiry, at the same Ride Lab taps that already gate today.
- After expiry: same screens, same teasers. Copy: keep segment zoom and full corners. Rides are never deleted.

Do **not** use a 7-day store trial. Riders need a few weekends to feel corner detail and segment zoom.

## Partner — 3 months via single-use invitation code

Staff-issued. Distinct from rodada join codes.

**Rules**

- Unique codes (e.g. `PRO-7K4M2Q`). One code → one account → **90 days full Pro**.
- Redeem in Settings (field + paste from share link). Invalid / already used / this account already redeemed a partner code → clear error.
- **One partner grant per account.** No stacking 3+3+3.
- Pro end becomes `max(current_pro_end, now + 90 days)` so unused trial days are not lost and a short remaining trial is not replaced by a shorter window.
- If they are **already paying**, do **not** consume the code; tell them it is unused so they can give it to someone else.
- Copy: “Partner Pro code” vs “Rodada invite.”

**Who gets codes:** dealerships / brand partners / press — issued by you, not self-serve.

## Paid subscription (when the store is ready)

Single entitlement id: `pro` (already used by RevenueCat in the app).

Packages:

- Monthly
- Yearly (default in the upgrade sheet; about two months free vs monthly)

No lifetime SKU at launch (refunds and account sharing). No family plan until Family Watch is a paid surface.

Play Console must flip from “no IAP” to subscriptions before this path is real. Sideload / closed testers can still use **trial + partner codes** without Play Billing.

Price (MXN + USD) is a later commercial pass. This matrix does not depend on the number.

## Entitlement model

Source of truth leaves the phone. Today `isPro` is local prefs or RevenueCat CustomerInfo only — partner trials cannot be trusted on-device.

Logical periods (any active ⇒ Pro):

| source | duration | starts |
|---|---|---|
| `trial` | 30 days | first completed ride |
| `partner` | 90 days | redeem |
| `revenuecat` | store period | purchase / restore |

Client keeps a boolean `isPro`. Server (Supabase) stores periods so staff impersonation, new devices, and sideload builds agree.

Partner codes (conceptual): `code` (unique), `duration_days=90`, `redeemed_by`, `redeemed_at`, `partner_label`, `created_by`. Single-use = `redeemed_by IS NULL`.

RevenueCat **promotional entitlements** can mirror partner/trial grants so Play and sideload stay in one CustomerInfo when billing is on. Until the API key is live, Supabase periods are enough for pilots.

## Engineering

Implemented in-app + Supabase (apply migration `20260824010000_pro_entitlements.sql`):

1. Tables `promo_codes` + `entitlement_periods`; RPCs `my_pro_status`, `start_pro_trial`, `redeem_partner_code`, `staff_create_partner_code`
2. Trial clock on first completed ride (local garage); 90-day signup cap on the server
3. Settings redeem UI + remaining-days copy; staff can mint single-use codes
4. RevenueCat packages (yearly first) when `REVENUECAT_API_KEY` is set — Play IAP still optional
