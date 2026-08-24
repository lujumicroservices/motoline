# Publish RiderLab to Google Play

Package ID: `com.rawthrottle.riderlab`  
App name on device: **RiderLab**

**Production runbook (listing copy, Data safety, closed test, submit):** [PLAY_PRODUCTION.md](PLAY_PRODUCTION.md)

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

Play App Signing is **quantum-ready**: testers are not signed with your upload keystore. Credential Manager `[16] Account reauth failed` means an **Android** OAuth client is missing the SHA-1 of the cert on the device.

Step-by-step (Previous + Classical + PQC + upload): **[PLAY_PRODUCTION.md](PLAY_PRODUCTION.md) §0**.

In [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials?project=riderlab-7b183) (project **riderlab-7b183**):

1. Keep **Web** client ID in `.env` as `GOOGLE_WEB_CLIENT_ID` (RiderLab Web, not `rawthrottle-admin`).
2. Create **one Android client per SHA-1**, package `com.rawthrottle.riderlab`:
   - **Previous** app-signing key (Android 16 and below — this is the usual tester phone)
   - **Classical** in-use app-signing key
   - **PQC** in-use app-signing key
   - **Upload** key (sideload APK only)
3. OAuth consent **Testing** → add tester Gmails.
4. Firebase Android app: add the same SHA-1 **and** SHA-256 fingerprints.

Get upload SHA-1:

```powershell
keytool -list -v -keystore android/upload-keystore.jks -alias upload
```

The app signs out before native Google, then falls back to browser OAuth (`com.rawthrottle.riderlab://login-callback`) if `[16]` still returns.

Supabase → Auth → Google: enable provider + **Manual linking**; paste Web client ID + secret. Add the redirect URL above.

---

## 4. Play Console listing checklist

Full paste-ready text: [PLAY_PRODUCTION.md](PLAY_PRODUCTION.md) §1. Assets: [docs/store/play/](store/play/).

| Item | Notes for RiderLab |
|---|---|
| Short / full description | Motorcycle GPS line + corner lab |
| App icon 512×512 | Adaptive icon already in app; export a 512 PNG for store |
| Feature graphic 1024×500 | Required banner |
| Phone screenshots | ≥2 (home, Ride Lab map, active ride) |
| Privacy policy URL | **Required** — `https://riderlab.rawthrottle.com.mx/legal/privacy.html` |
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

---

## 8. Automate Internal testing uploads

Two pieces:

1. **Local build** (this PC): bump version + produce the AAB.
2. **GitHub Action `play-release`**: build the same AAB in CI and push it to the **internal** track.

Google Sign-In SHA fingerprints stay in Cloud/Firebase — that is not part of this pipeline.

### Local AAB

```powershell
cd apps/mobile
powershell -ExecutionPolicy Bypass -File tool/release_play.ps1 -BumpPatch
```

Omit `-BumpPatch` to rebuild the current `pubspec.yaml` version. Then either upload the printed `.aab` in Play Console, or commit the version bump and run the Action.

### One-time Play API access

1. [Google Cloud](https://console.cloud.google.com/) project **riderlab-7b183** → **IAM & Admin** → **Service accounts** → **Create**.
2. Name: `play-release`. Create a **JSON** key. Store the file offline; do not commit it.
3. Play Console → **Users and permissions** → **Invite new users** → paste the service account email (`play-release@riderlab-7b183.iam.gserviceaccount.com`).
4. App permissions: **RiderLab** → **Release to production, exclude devices, and use Play App Signing** (or at least release to testing tracks) → **Invite**.
5. Enable [Google Play Android Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=riderlab-7b183).

### GitHub secrets (repo Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | Entire JSON key file contents |
| `PLAY_KEYSTORE_BASE64` | Base64 of `apps/mobile/android/upload-keystore.jks` |
| `PLAY_KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `PLAY_KEY_PASSWORD` | `keyPassword` from `key.properties` |
| `PLAY_KEY_ALIAS` | `upload` |
| `MOBILE_ENV` | Entire `apps/mobile/.env` |
| `GOOGLE_SERVICES_JSON` | Entire `apps/mobile/android/app/google-services.json` |

Encode the keystore on this PC:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("apps\mobile\android\upload-keystore.jks")) | Set-Clipboard
```

### Run a Play drop

1. Commit the `pubspec.yaml` version bump (`versionCode` must increase every time).
2. GitHub → **Actions** → **play-release** → **Run workflow** → track **internal**.
3. Testers update from the same internal testing link. No new opt-in needed.

The Action marks the release **completed** on Internal testing (`changesNotSentForReview: true`). It does **not** promote to Production.
