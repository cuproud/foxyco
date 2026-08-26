# Firebase setup

Firebase stores authentication and one server-stamped trial record. It does not
receive offers, screenshots, location, earnings history, or analytics.

## Project

1. Create a Firebase project with Google Analytics disabled.
2. Register Android package `com.foxyco.app`.
3. Add the debug, upload, and Google Play App Signing SHA-1 fingerprints.
4. Download the refreshed `google-services.json` to
   `android/app/google-services.json`. It is gitignored and must not be
   committed.
5. Enable Anonymous and Google Authentication. FoxyCo uses Google Sign-In 6.x
   and the generated default web client ID.
6. Set the OAuth consent screen to production with the public home, privacy,
   and terms URLs. FoxyCo requests only basic identity scopes.

## Firestore

Create a production-mode database, then deploy the repository rules:

```bash
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

Verify them locally:

```bash
npm install
npm run test:rules
```

The rules allow an authenticated owner to create and read only their own
write-once, server-stamped trial record. Client-selected timestamps, updates,
deletes, cross-account access, anonymous misuse, and all other paths are denied.

## Google Play

Create `foxyco.lifetime` as a non-consumable product. Copy the Play licensing
RSA public key and build through `scripts/build.sh`; the release build fails
closed if signing or the key is missing. Billing test accounts and track
membership are separate settings.

After the first Play upload, add the Play App Signing SHA-1 to Firebase and
download `google-services.json` again. Repeat this after any signing-key
rotation.

## Verification

On a Play-installed build, verify:

- anonymous startup and Google trial sign-in;
- the same account cannot restart the trial after reinstall;
- purchase acknowledgement, restore, and refund/revoke behavior;
- account deletion removes Firebase Auth while the disclosed anti-abuse trial
  row remains; and
- no Firebase Analytics events or offer data are sent.
