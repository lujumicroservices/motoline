# Publish RiderLab to Google Play

Package ID: `com.motoline.motoline`  
App name on device: **RiderLab**

You cannot finish Play Console signup from this repo alone — Google needs your developer account, listing assets, and a one-time upload. This guide gets the **signed App Bundle** ready and lists every Console step.

---

## 0. What only you can do (account)

1. Open [Google Play Console](https://play.google.com/console) and pay the **one-time $25** developer fee (if you do not have an account yet).
2. Create app → **RiderLab** → app type **App** → Free or Paid.
3. Complete **Dashboard** checklist items (privacy, content rating, target audience, Data safety, etc.).

---

## 1. Create the upload keystore (once)

From `apps/mobile`:

```powershell
powershell -ExecutionPolicy Bypass -File tool/create_play_keystore.ps1
```

That writes (both **gitignored**):

- `android/upload-keystore.jks`
- `android/key.properties`

**Back these up offline forever.** If you lose them, you cannot ship updates to the same Play listing (unless you enrolled in Play App Signing recovery options).

Copy template only if you create the keystore yourself:

```text
apps/mobile/android/key.properties.example  →  key.properties
```

---

## 2. Build the Play App Bundle (AAB)

```powershell
cd apps/mobile
flutter gen-l10n
flutter build appbundle --flavor play --release --dart-define=DISTRIBUTION=play
```

Output:

```text
build/app/outputs/bundle/playRelease/app-play-release.aab
```

Upload **that `.aab`** in Play Console → **Production** (or Internal testing first).

### Friend / GitHub sideload APK (unchanged path)

```powershell
flutter build apk --flavor sideload --release --dart-define=DISTRIBUTION=sideload
```

Sideload keeps GitHub in-app APK updates. **Play flavor removes** `REQUEST_INSTALL_PACKAGES` (required for Play policy).

---

## 3. Google Sign-In for Play builds

In [Google Cloud Console](https://console.cloud.google.com/auth/clients):

1. Keep your **Web** client ID in `.env` as `GOOGLE_WEB_CLIENT_ID`.
2. Ensure an **Android** OAuth client exists for:
   - Package name: `com.motoline.motoline`
   - SHA-1 of your **upload** keystore **and** the **Play App Signing** certificate (Play Console → Setup → App signing — Google shows the app signing SHA-1 after first upload).

Get upload SHA-1:

```powershell
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

Add both SHA-1 fingerprints to the Android OAuth client (or create two Android clients).

Supabase → Auth → Google: enable provider + **Manual linking**; paste Web client ID + secret.

---

## 4. Play Console listing checklist

| Item | Notes for RiderLab |
|---|---|
| Short / full description | Motorcycle GPS line + corner lab |
| App icon 512×512 | Adaptive icon already in app; export a 512 PNG for store |
| Feature graphic 1024×500 | Required banner |
| Phone screenshots | ≥2 (home, Ride Lab map, active ride) |
| Privacy policy URL | **Required** — host [docs/legal/privacy.html](legal/privacy.html); see [STORE_READINESS.md](STORE_READINESS.md) |
| App category | Health & fitness / Maps / Sports (pick closest) |
| Content rating | IARC questionnaire |
| Target audience | Typically 18+ (driving / motorcycle) |
| **Data safety** | Location (precise, background while riding), App activity optional, Account (Google) |
| **Sensitive permissions** | Background location — must declare prominent in-app disclosure + Play declaration form |
| Ads | Declare if Free tier shows ads |
| Countries | Select distribution |

### Background location (critical)

Play will ask why you need background location. Answer honestly: **continue recording the motorcycle GPS line with screen off / phone in pocket while riding**, foreground service notification visible.

---

## 5. Recommended release path

1. **Internal testing** track → upload AAB → add your Gmail as tester → install from Play internal link  
2. Fix review issues  
3. **Closed testing** (friends)  
4. **Production**

Do **not** rely on GitHub APK updates for Play users — they update only through Play.

---

## 6. Local run with flavors

```powershell
flutter run --flavor play --dart-define=DISTRIBUTION=play
flutter run --flavor sideload --dart-define=DISTRIBUTION=sideload
```

---

## 7. After first production approve

- Turn on Play App Signing (default)  
- Copy **App signing** SHA-1 into Google OAuth Android client  
- Bump `version:` in `pubspec.yaml` for every new upload (`1.21.0+27`, etc.)  
- Build a new play AAB and promote the release  

Questions while filling Console forms: privacy policy hosting, feature graphic, or Data safety wording — ask and we can draft copy.
