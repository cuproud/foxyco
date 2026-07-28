# Firebase & Play Console setup (what only YOU can do)

**Written:** 2026-07-28, alongside the M11 billing branch.
**Companion:** `MONETIZATION_v1.0.md` (why any of this exists), `PLAY_RELEASE.md` (store listing).

The code for the trial and the unlock is written and `flutter test` is green. None
of it can run on a device until the console work below is done, because there is
no `android/app/google-services.json` in the repo (it is per-project and not
ours to invent).

> **The Android build FAILS until step 2 is done.** The `com.google.gms.google-services`
> Gradle plugin is applied in `android/app/build.gradle.kts` and it hard-errors
> when the JSON is missing. That is deliberate: a build that silently skipped
> Firebase would ship an app whose trial never starts.

---

## 1. Create the Firebase project (free, no card)

1. <https://console.firebase.google.com> → **Add project** → name it `foxyco`.
   Google Analytics: **off** (we declare no analytics — see §5 of the
   monetization doc; enabling it would make the Data safety form wrong).
2. Spark (free) plan is enough: anonymous auth, Google sign-in, and one Firestore
   document read per driver per check. No Blaze, no Cloud Functions.

## 2. Register the Android app and drop in the config

1. Project settings → **Add app** → Android.
2. **Package name: `com.foxyco.app`** — the `applicationId` from
   `android/app/build.gradle.kts`, NOT the Kotlin source package
   (`com.foxyco.foxyco`, which is a different string and a classic hour lost).
   A mismatch fails sign-in with a `DEVELOPER_ERROR` that explains nothing.
3. Download `google-services.json` → put it at **`android/app/google-services.json`**.
   It is gitignored (`android/.gitignore`) — it identifies your Firebase project
   and each developer/CI environment supplies its own.

## 3. Register the UPLOAD key's SHA-1 — before testing sign-in

Google Sign-In fails on a debug/internal build whose signing fingerprint Firebase
does not know. This is step 1b in the build order and it blocks everything after.

```bash
# Debug key (for `flutter run`)
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA1

# Your upload key (for internal/closed-track builds)
keytool -list -v -alias upload -keystore ~/foxyco-upload.jks | grep SHA1
```

Add **both** SHA-1s in Firebase → Project settings → your Android app →
*Add fingerprint*. Then **re-download `google-services.json`** — the file changes
when fingerprints are added, and the stale copy is a very confusing failure.

## 4. Turn on the two auth providers

Firebase → Authentication → Sign-in method → enable:

- **Anonymous** — the silent identity every install gets at first launch.
- **Google** — what the driver upgrades to when they tap "Start 7-day trial".

Enabling Google creates a **Web client ID** in the generated
`google-services.json`, which the Gradle plugin turns into
`R.string.default_web_client_id`. `google_sign_in` 7.x picks that up on its own,
which is why no client ID is hardcoded anywhere in `lib/`.

## 5. Create Firestore and deploy the rules

1. Firebase → Firestore Database → **Create database** → production mode, region
   nearest your drivers.
2. Deploy the rules from this repo — they ARE the backend:

```bash
npm i -g firebase-tools     # once
firebase login
firebase use --add          # pick the foxyco project
firebase deploy --only firestore:rules
```

`firestore.rules` makes `trials/{uid}` **write-once, server-stamped, never
updatable or deletable**. Without it deployed, the default production rules deny
everything and every trial start fails with `permission-denied`.

## 6. Play Console: the product and the licensing key

Blocked until the developer account finishes ID verification.

1. Monetization → Products → **In-app products** → create
   **`foxyco.lifetime`**, type **non-consumable**, price **$12.99**, then use the
   price template to fill other countries and round the odd amounts.
2. Monetization setup → **Licensing** → copy the Base64 RSA public key.
3. Build with it — the app verifies every receipt against this key locally, and
   **denies all purchases when it is absent** (fail closed, §3.9):

```bash
flutter build appbundle --dart-define=PLAY_PUBLIC_KEY=<paste the base64 key>
```

   A release build without this define locks out every paying customer. The app
   detects it and says so in the paywall sheet, but do not ship it.
4. Closed-track builds should also carry a kill date so a tester copy can't live
   forever (§6):

```bash
flutter build appbundle \
  --dart-define=PLAY_PUBLIC_KEY=<key> \
  --dart-define=BUILD_EXPIRY=2026-09-30
```

5. License testing → add tester Gmails so they can exercise the purchase flow
   with a test card. **Clear this list at production launch** or those testers
   keep a free copy.

## 7. After the FIRST bundle upload — the second SHA-1

Play re-signs your upload with **Play App Signing**, and that key's fingerprint
does not exist until Google has your first bundle. Once it does:

Play Console → Release → Setup → App signing → copy the **SHA-1 of the app
signing certificate** → add it in Firebase → re-download `google-services.json`
→ rebuild.

Skip this and you get the classic bug: **Google Sign-In works all through
development and fails in production.**

---

## What is still not built (deliberate, tracked)

- **Resigned-repack detection** (§3.7 layer 3, the signing-certificate check).
  It needs a fingerprint to compare against, and the Play App Signing one does
  not exist until step 7 above. Building it now would mean shipping a check
  against a placeholder. Revisit after the first upload.
- **Privacy policy + account-deletion web pages** (§5, §5.1). Play requires both
  URLs to be live before review. The in-app deletion path exists
  (Settings → Unlock → Delete my account).
