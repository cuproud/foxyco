# Google Play release runbook

Updated 2026-08-28 for `1.0.11+99`.

## Before building

- Package name stays `com.foxyco.app`.
- Upload-key signing is configured through the ignored
  `android/key.properties`; never commit the keystore or passwords.
- Firebase has the debug, upload, and Play App Signing SHA-1 fingerprints.
- Firebase Anonymous and Google sign-in are enabled, Analytics is off, and the
  repository Firestore rules are deployed.
- `foxyco.lifetime` exists as a non-consumable Play product.
- Legal URLs are public and match `lib/ui/legal/legal_links.dart`.
- Any offer-logic changes are reconciled with `docs/OFFER_DETECTION.md` and its
  required parser/watcher and real-device checks.

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

For the Play Console Accessibility Services declaration, select **App
functionality** only and answer **No** to collecting or sharing personal or
sensitive data through Accessibility. Offer text, temporary screenshots, and
derived history stay on the device; Firebase account and purchase traffic does
not contain Accessibility-derived data.

Use this implementation-accurate purpose statement:

> FoxyCo receives screen-change events from selected supported driver apps and
> temporarily reads offer text to identify pay, distance, duration, and
> delivery workload so it can display a read-only earnings verdict. If the
> driver selects Uber on Android 11 or newer, a selected-app event can trigger
> one rate-limited Accessibility screenshot for on-device Uber OCR. Screenshots
> and raw text are immediately discarded and are never saved or sent. FoxyCo
> never taps, accepts, declines, or controls another app.

The review video must show the app opening, the full in-app disclosure, **Not
now**, the user trying again and seeing the disclosure again, **Agree & open
settings**, the Android permission grant, Rules → Watched apps → Uber, and one
real verdict. Blur rider names and pickup/drop-off addresses before uploading.
The video should also make clear that FoxyCo performs no automated action. Do
not promise approval; Google makes the final policy decision.

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

## Closed-tester access through 2026

Use Play-managed entitlements; do not add a tester allowlist or ship with
`BUILD_EXPIRY`. Closed-test enrollment and License testing are separate Play
Console settings, and every tester must use the same Google account to opt in,
install FoxyCo, and make or redeem a purchase.

### Tester groups

Keep exactly one private ledger outside this repository. Never commit tester
emails, promo codes, or Play order IDs.

| Group | Size | Access | Play setup | End of access |
| --- | ---: | --- | --- | --- |
| Lifetime contributors | 3–5 | Permanent | One unique `foxyco.lifetime` promo code each | Never revoke |
| Temporary closed testers | Everyone else | Complimentary through 2026 | License tester + approved test purchase | Manually refund and revoke after 2026-12-31 |

Ledger columns:

`Google account | group | closed opt-in date | trial start date | promo/test order ID | access verified | revoke due | revoked`

Do not place a lifetime contributor in the temporary License testing list when
they redeem their promo code. Confirm that the redemption appears as ownership
of `foxyco.lifetime`, then record the order ID and mark it **never revoke**.

### Start the closed test

1. Add all testers to the Closed testing list or Google Group and share the
   closed-test opt-in link.
2. Confirm at least 12 testers are opted in; keep about 20 enrolled as a buffer.
   A tester who switches to Internal testing no longer counts toward Closed.
3. Ask testers to install from Google Play with the same account used to opt in.
4. Have temporary testers start and exercise the normal 7-day trial first. The
   trial starts only when they tap **Start trial**, not when they opt in.
5. Add the temporary group under Play Console **Settings → License testing**.
6. Before or after the trial expires, have each temporary tester tap **Unlock
   forever** and choose **Test card, always approves**. The purchase dialog must
   identify it as a test purchase; no real payment method should be used.
7. Verify the app reports lifetime access, restart it, tap **Restore purchase**,
   and record the Play test order ID. This is temporary test ownership even
   though the app correctly labels Play's non-consumable product as lifetime.

License testing does not enroll anyone in the Closed track, and removing an
account from License testing does not revoke an acknowledged test purchase.

Send temporary testers this wording:

> FoxyCo provides complimentary full access to closed testers through December
> 31, 2026. This is a revocable Google Play test entitlement. Continued access
> afterward requires the one-time lifetime purchase. Please use only Google's
> “Test card, always approves” when instructed; you will not be charged.

### Revoke temporary access after 2026-12-31

For every temporary tester, starting 2027-01-01:

1. Open Play Console **Order management** and find the recorded test order.
2. Confirm the account and product ID are correct and the ledger does not mark
   the order **never revoke**.
3. Select **Refund and revoke**. Removing the License testing account alone is
   insufficient.
4. Remove the account from **Settings → License testing**.
5. Ask the tester to open FoxyCo online or tap **Restore purchase**, then verify
   that the app returns to locked/paywall state.
6. Record the revocation date and result. FoxyCo may honor its cached purchase
   for up to seven days while a device remains offline; it drops access as soon
   as Play returns a successful no-ownership result.

Do not revoke lifetime promo-code orders. If an order cannot be matched
unambiguously to the ledger, stop and verify the Google account before acting.

### Console-only checks

- `foxyco.lifetime` remains active and non-consumable.
- Canada is explicitly CAD 24.99 and the United States explicitly USD 19.99.
- Temporary purchases show Google's test-purchase notice and no charge.
- Promo codes are unique one-time codes; their redemption deadline does not
  make redeemed lifetime ownership expire.
- Tester/list changes and test-order revocations require no app build. Any
  billing implementation change must be verified on Internal before Closed.

## Release evidence to retain

- version, artifact filename, SHA-256, and upload time;
- Flutter/analyzer/rules/Android lint results;
- tested Android and selected-app versions;
- redacted OCR/Accessibility consent recording;
- purchase/restore/revoke results; and
- crash, ANR, battery, cross-app latency, and stale-overlay observations.

Never retain rider names, addresses, raw Accessibility text, screenshots, or
OCR output in release evidence.
