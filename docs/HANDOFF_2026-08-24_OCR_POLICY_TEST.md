# FoxyCo handoff — build 85 Play billing and Uber OCR test

**Date:** 2026-08-25  
**Branch:** `main`  
**Source version:** `1.0.10+85`

## Current state

FoxyCo is a gig-driver utility, not a disability accessibility tool. The local
test source therefore now declares:

```xml
android:isAccessibilityTool="false"
```

This does **not** disable the Android Accessibility service. Accessibility must
remain enabled because it supplies watched-app events, readable nodes for apps
such as Lyft/Hopp, and Android's screenshot capability. The opt-in OCR setting
is a fallback only: when an active offer frame is missing enough accessibility
text to parse, FoxyCo takes one memory-only screenshot, runs bundled ML Kit
Latin recognition, wipes the bitmap, and sends the recognized lines through
the triggering platform's existing parser.

Expected behavior with this test build:

- **Uber:** Android 14+ may hide `accessibilityDataSensitive` offer nodes from a
  non-tool service, so the OCR fallback is expected to provide the verdict.
- **Lyft and Hopp:** accessibility parsing should remain primary; OCR runs only
  if a visible offer cannot be read completely.
- **DoorDash, Instacart and Skip:** parser fixtures pass, but live-device support
  is still beta and must not be represented as fully verified.

Build 85 also removes guessed purchase prices. The paywall waits for Google
Play's localized `ProductDetails.price`, shows an unavailable state when Play
cannot return the product, and refreshes product details instead of retaining
them for the process lifetime. Canada, the United States, Mexico and future
countries therefore use only their configured Google Play price.

## Local test artifact

Installed/test artifact:

```text
dist/FoxyCo-v1.0.10+83-release-20260824-2302.apk
SHA-256: 623e1bce6d47b85a5943ad87788659050ca51e74d22b4ce6a981593cdd5b6b14
```

The compiled APK was inspected with `aapt2`; its packaged accessibility XML
contains both `android:isAccessibilityTool=false` and
`android:canTakeScreenshot=true`. It is signed with the FoxyCo upload
certificate. It was built without `PLAY_PUBLIC_KEY`, so it is for local OCR
testing, not purchase/restore validation. The user uninstalled the prior copy
and successfully installed this APK after Android rejected an in-place update,
most likely because the installed Play copy and local APK used different
signing certificates.

Play test artifact:

```text
dist/FoxyCo-v1.0.10+85-release-20260825-0025.aab
SHA-256: 06098eccc9f6ec9e704f84fa63a56a125ce75f88a9d88cdee1ccffad10ad28b4
```

This AAB is signed with the FoxyCo upload certificate and includes the Play
licensing key. Install it through a Play testing track; do not sideload an APK
for purchase or restore validation.

## Build 85 changes

```text
android:isAccessibilityTool=false with its contract test
Google Play localized pricing only; no guessed USD/CAD fallback
ProductDetails refreshed on Play reconciliation
History: "No accepted offers in this view"
Last session: "No accepted offers this session"
```

The accessibility contract locks the policy-safe `isAccessibilityTool=false`
classification. Build 85 is for the Play testing track, not production
promotion; the real Uber OCR test remains the production gate.

## Verification completed

- `flutter analyze --no-pub`: passed.
- Accessibility contract, `OfferWatcher`, and all parser tests: **130 passed**.
- Tests cover accessibility-first behavior, incomplete/textless-frame OCR
  fallback, cancellation, platform-bound OCR results, and parser fixtures.
- Full Flutter suite: **515 passed**; Firestore rules tests passed.
- Signed/minified build-85 Play AAB compiled successfully.
- Existing Cupertino icon-family warning appeared; it is unrelated to OCR and
  Material Icons were packaged normally.

Automated tests cannot prove that the current Uber release permits Android's
Accessibility screenshot or that recognition finishes before a real offer
expires. That is tomorrow's release gate.

## Tomorrow: Play install and Uber device test

Before going live:

1. Publish build 85 to the internal testing track and wait for Play delivery.
2. Uninstall the sideloaded APK, opt in, and install FoxyCo from Google Play.
3. Confirm Settings → About shows build 85.
4. Use the Play account that owns `foxyco.lifetime`; tap **Restore purchase**
   and confirm **Lifetime unlocked**.
5. Android Settings → Accessibility → Installed apps → FoxyCo: **ON**.
6. FoxyCo → Settings → App health → Offer detection.
7. Enable **Screen-reading fallback**, accept **Enable OCR**.
8. Return Home and slide to go live.

Test at least 5–10 real Uber offers, including different card variants when
available. Record for each offer:

- whether a verdict appeared;
- delay from card appearance to verdict;
- payout, pickup/total distance and time correctness;
- whether the pill clears when the card disappears;
- whether one offer creates exactly one History row;
- any failure shown in Offer detection or Diagnostic logs.

Also sanity-check one Lyft and one Hopp offer if practical. They should still
parse through accessibility without requiring OCR.

If Uber succeeds consistently, keep build 85 as the tested release candidate
and complete the Play declaration as a non-accessibility-tool use. If it fails,
preserve screenshots and diagnostics; do not restore
`isAccessibilityTool=true` merely to pass parsing.

## OCR repository decision

[`SubhamTyagi/android-ocr`](https://github.com/SubhamTyagi/android-ocr) was
reviewed. It is a standalone Tesseract 5 application optimized for manually
selected images and 120+ languages. FoxyCo already has the smaller, faster path
needed for transient English offer cards: Android screenshot capture plus
bundled ML Kit Latin OCR and platform parsers. Tesseract was not added because
it would increase binary size, initialization cost and maintenance without
changing Android screenshot access.

## History export and restore

Uninstalling clears FoxyCo's local SharedPreferences history because Android
backup is disabled. The current **Export CSV** action is an analytical export,
not a lossless backup, and there is currently no import action.

The current CSV includes timestamps, platform, category, queued/delivery
metadata, verdict, displayed currency/unit, upfront payout, bonus, converted
distance/time/rates and outcome. It omits or rounds data needed for a perfect
round trip, including:

- manually entered final payout;
- manual-outcome and detected-outcome metadata;
- the scoring snapshot used when the verdict was produced;
- raw full-precision distance and duration values.

The user intended to export the current CSV before uninstalling; confirm that
the file exists and contains rows. Next-session restore work should provide:

1. a versioned lossless JSON backup using `OfferSummary.toJson()` values;
2. local document-picker import with file-size, schema, enum and numeric-range
   validation;
3. parse-and-validate before mutation, so an invalid file changes nothing;
4. deterministic duplicate-safe merge capped at `OfferLog.maxEntries`;
5. legacy CSV import for the already-exported file, clearly acknowledging that
   fields absent from that CSV cannot be reconstructed;
6. no network transfer, logging of offer contents, or personal backup committed
   into the repository.

Do not embed the user's CSV in a committed or distributable APK. If a one-off
local seeded APK is ever required, keep the data untracked and explain that the
APK itself then contains readable personal history.

## Play Console context

The earlier build-83 AAB was produced while `isAccessibilityTool=true`, causing
Play Console to request a disability-purpose declaration that FoxyCo cannot
truthfully make. Build 85 uses `false` plus OCR for Uber's hidden nodes. The
separate foreground-service special-use declaration still applies to the
user-started live overlay session. The review video already provided is:

```text
https://www.youtube.com/watch?v=MJdLCbdXCUI
```

It demonstrates starting Go live, the persistent overlay over Uber, returning
to FoxyCo, and stopping the session. It supports the foreground-service review;
it is not by itself an accessibility/OCR disclosure video.
