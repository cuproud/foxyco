# Google Play release runbook

Updated 2026-08-26 for `1.0.10+90`.

## Before building

- Package name stays `com.foxyco.app`.
- Upload-key signing is configured through the ignored
  `android/key.properties`; never commit the keystore or passwords.
- Firebase has the debug, upload, and Play App Signing SHA-1 fingerprints.
- Firebase Anonymous and Google sign-in are enabled, Analytics is off, and the
  repository Firestore rules are deployed.
- `foxyco.lifetime` exists as a non-consumable Play product.
- Legal URLs are public and match `lib/ui/legal/legal_links.dart`.

## Build

Use the helper. It runs analysis, Flutter tests, Firestore rules tests, version
checks, signing checks, and the release bundle build.

```bash
./scripts/build.sh aab
```

The licensing key is public, but a bundle without it rejects every purchase.
The helper deliberately extracts the canonical command below when
`PLAY_PUBLIC_KEY` is not set; keep this exact line available.

flutter build appbundle --dart-define=PLAY_PUBLIC_KEY=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqTpiV2mIQJeDVeoIRmabFXEFHtfr1lPWYV56M3GX/fR4D3gqG7YpPRYVKN5JoOB4Pv8qS2Q8VKEv1FGXQODLUxWvhDWSxev0WBHfHUwPS2ZlBbNm+U2dd/Gx9Wf9dvhHZku0oP2hvacWEhHR0Q6Q4Q7TJUxuXoPtkayM6aeagFL7pmw1wUNVKeVyHX9CufKTJdjc48++BACM712kUc5CHpwCcRO5E+MhG9bt0vwWJizNrvNG9iREzPHeMgsaQX5Oeco+sWyC1b5okHiYkmmZMG1Z8S9fqnM8bw90HoA/8EnNkbt/+ZMo4E0D/jzor8RpF+gtTFGMAkzXQilW1OaJqQIDAQAB

Do not use `BUILD_EXPIRY` for normal internal, closed, or production builds.
It is an expiry-test switch, not tester access, and never overrides a verified
lifetime purchase.

## Play declarations

### Accessibility

`android:isAccessibilityTool` is `false`. This avoids the false claim that
FoxyCo is an accessibility aid; it does not remove the declaration requirement.

Use this implementation-accurate purpose statement:

> FoxyCo receives screen-change events from selected supported driver apps and
> temporarily reads offer text to identify pay, distance, duration, and
> delivery workload so it can display a read-only earnings verdict. If the
> driver separately enables Uber screen-reading fallback on Android 11 or
> newer, a selected-app event can trigger one rate-limited Accessibility
> screenshot for on-device Uber OCR. Screenshots and raw text are immediately
> discarded and are never saved or sent. FoxyCo never taps, accepts, declines,
> or controls another app.

The review video should show the in-app prominent disclosure, affirmative
consent, Android permission screen, optional separate Uber OCR disclosure, one
verdict, and that FoxyCo performs no automated action. Do not promise approval;
Google makes the final policy decision.

### Data safety and account deletion

Keep Console answers aligned with `docs/legal/privacy.md`:

- declare the Firebase user identifier, Google account information used for
  trial sign-in, and trial/purchase state with the applicable security,
  service, and fraud-prevention purposes;
- do not declare offer text, screenshots, location, analytics, or card data as
  collected by FoxyCo because they are not transmitted to FoxyCo;
- provide both the in-app deletion path and
  `https://cuproud.github.io/foxyco/legal/delete-account.html`;
- disclose that the random identifier and server-stamped trial start remain
  after account deletion for trial-abuse prevention.

Re-check the form whenever Firebase, logging, feedback, OCR, billing, or account
behavior changes.

## Track order

1. Upload to Internal testing and install through Google Play.
2. Verify Google sign-in and one licensed test purchase on the Play-signed app.
3. Verify acknowledgement, restore, reinstall, refund/revoke, and offline grace.
4. Promote the same artifact to Closed testing and satisfy the tester duration
   and participation requirement displayed for this developer account.
5. Complete `MANUAL_TESTS.md`, review Play Vitals, then request production.

## Release evidence to retain

- version, artifact filename, SHA-256, and upload time;
- Flutter/analyzer/rules/Android lint results;
- tested Android and selected-app versions;
- redacted OCR/Accessibility consent recording;
- purchase/restore/revoke results; and
- crash, ANR, battery, cross-app latency, and stale-overlay observations.

Never retain rider names, addresses, raw Accessibility text, screenshots, or
OCR output in release evidence.
