# Store readiness — RiderLab

Use with [PLAY_STORE.md](PLAY_STORE.md). Hosted legal pages (host these URLs in Play / App Store Console):

- Privacy: ship `docs/legal/privacy.html`
- Terms: ship `docs/legal/terms.html`

Suggested public paths (hosted on `riderlab.rawthrottle.com.mx`):

```text
https://riderlab.rawthrottle.com.mx/legal/privacy.html
https://riderlab.rawthrottle.com.mx/legal/terms.html
```

Source files: `docs/legal/privacy.html`, `docs/legal/terms.html`.
---

## Google Play (internal → production)

Paste-ready listing, Data safety, closed-test, and Production steps: **[PLAY_PRODUCTION.md](PLAY_PRODUCTION.md)**. Art: [docs/store/play/](store/play/).

- [x] Developer account + app created (**RiderLab**)
- [x] Signed AAB (`--flavor play`) uploaded to **Internal testing**
- [ ] Play Google Sign-In on a Play install ([PLAY_PRODUCTION.md](PLAY_PRODUCTION.md) §0 — three Android OAuth SHA-1s)
- [ ] Privacy policy URL set (`https://riderlab.rawthrottle.com.mx/legal/privacy.html`)
- [ ] Data safety: precise location (background while riding), account (Google); **Contains ads: No**
- [ ] Background location declaration (copy in PLAY_PRODUCTION.md / below)
- [x] In-app prominent disclosure before first background grant (permission flow already requests location)
- [ ] Content rating (IARC), target audience 18+
- [ ] Screenshots + feature graphic (`docs/store/play/`)
- [ ] Closed testing ≥12 opted-in testers, live **14 days** (personal accounts)
- [ ] Production release from the **same** AAB → Send for review

---

## Apple TestFlight / App Store

- [ ] Apple Developer Program membership
- [ ] Xcode archive with `UIBackgroundModes=location` + purpose strings (already in `Info.plist`)
- [ ] Privacy Policy + Terms URLs in App Store Connect
- [ ] App Privacy nutrition labels mirror Play Data safety
- [ ] TestFlight internal group → external → App Review
- [ ] Safety copy in review notes: “Do not interact with the phone while riding; analysis is post-ride.”
- [ ] Sign in with Apple only if you add non-Google options later (currently Google / guest)

---

## Background location justification (copy/paste)

**Short:** Continue recording the motorcycle GPS line with the screen locked or the phone in a pocket while riding.

**Long:** RiderLab’s core feature is an accurate post-ride map of the line taken. Riders cannot safely hold or glance at the phone. Background location (Android foreground service + iOS location background mode) keeps sampling GPS/IMU after the screen turns off until the rider ends the ride. A persistent notification is shown on Android. Location is not used for ads or continuous tracking outside an active ride / opt-in rodada.

---

## RevenueCat / Pro (when keys are set)

Product contract (Free vs Pro, 30-day trial, 90-day partner codes): **[FREE_VS_PRO.md](FREE_VS_PRO.md)**.

1. Create RevenueCat project + App Store / Play apps  
2. Entitlement id: **`pro`** (single entitlement; monthly + yearly packages when IAP is live; yearly is the default in the upgrade sheet)  
3. Put public SDK key in `apps/mobile/.env` as `REVENUECAT_API_KEY`  
4. Settings → Restore purchases appears; Upgrade uses store packages  

Until the key is set, Pro remains the local Settings toggle for sideload pilots. Trial and partner grants are specified in FREE_VS_PRO.md and ship on Supabase **before** Play Billing — they do not wait on this checklist.

Do not pitch “no ads” as a Pro benefit until a real ads SDK is live. Play Data safety currently: **Contains ads: No**.
