# Store readiness — RiderLab

Use with [PLAY_STORE.md](PLAY_STORE.md). Hosted legal pages (host these URLs in Play / App Store Console):

- Privacy: ship `docs/legal/privacy.html` (e.g. Azure static site or your domain)
- Terms: ship `docs/legal/terms.html`

Suggested public paths (hosted on partner Azure static site):

```text
https://riderlabdeck.z21.web.core.windows.net/legal/privacy.html
https://riderlabdeck.z21.web.core.windows.net/legal/terms.html
```

Source files: `docs/legal/privacy.html`, `docs/legal/terms.html`.
---

## Google Play (internal → production)

- [ ] Developer account + app created (**RiderLab**)
- [ ] Signed AAB (`--flavor play`) uploaded to **Internal testing**
- [ ] Privacy policy URL set
- [ ] Data safety: precise location (background while riding), account (Google), app activity optional
- [ ] Background location declaration: record motorcycle GPS with screen off / pocket; FGS notification visible
- [ ] In-app prominent disclosure before first background grant (permission flow already requests location)
- [ ] Content rating (IARC), target audience 18+
- [ ] Screenshots + feature graphic
- [ ] Closed testing with friends → Production

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

1. Create RevenueCat project + App Store / Play apps  
2. Entitlement id: `pro`  
3. Put public SDK key in `apps/mobile/.env` as `REVENUECAT_API_KEY`  
4. Settings → Restore purchases appears; Upgrade uses store packages  

Until the key is set, Pro remains the local Settings toggle for sideload pilots.
