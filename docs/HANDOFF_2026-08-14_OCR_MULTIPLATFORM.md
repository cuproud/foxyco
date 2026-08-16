# FoxyCo handoff — OCR, multi-platform parsing, and overlay stability

**Date:** 2026-08-15  
**Workspace:** `/home/vamsi/github/foxyco`  
**Current device:** Samsung SM-S928W  
**Latest wireless ADB serial:** `192.168.2.10:39941`

## Resume objective

Upload/install build 32, then validate it on real Uber, Lyft, and Hopp cards,
including overlapping offers. The top visible offer must own the verdict. When
it closes, the next active offer must replace it without a bubble/pill flicker,
duplicate History row, duplicate outcome, or repeated voice alert.

Do not remove Android Accessibility parsing. Pixel Capture OCR is an optional,
on-device fallback and a debug-test path; Accessibility remains the primary
production input.

## Latest checkpoint — 2026-08-15

- Full release preflight passed in the normal WSL shell: dependencies, Flutter
  analysis, the complete Flutter test suite, and Firestore rules tests.
- Play rejected another build-code `31` upload because that code had already
  been used. Do not upload either build-31 bundle again.
- `./scripts/build.sh aab --bump` advanced the source to `1.0.9+32` and built:
  `dist/FoxyCo-v1.0.9+32-release-20260815-0057.aab` (about 81 MB locally;
  Google Play splits it per device).
- The CupertinoIcons build message is harmless: FoxyCo has no CupertinoIcons
  references, Material Icons are bundled, and the release bundle completed.
- Build 32 upload/Play-install status was not recorded before pausing. Resume by
  uploading that exact AAB; do not bump again unless Play says code 32 was used.

Features included in build 32:

- transparent SurfaceView overlay fix for the grey rectangular mask;
- exact-offer outcome binding plus persistent manual History corrections;
- GOOD-only Android system voice, independent Rules toggle, preview, and
  `QUEUE_FLUSH` replacement so offer floods cannot create a spoken backlog;
- USD, CAD, AUD, NZD, MXN, and BRL display choices without FX conversion;
- new installs seed currency/distance defaults from Google Play's billing
  country, while saved driver choices remain untouched.

## Play build field follow-up (2026-08-14, later shift)

The Play Store build was tested with Uber and Lyft open alongside FoxyCo.
Evidence:

- `Screenshot_20260814_163131_Lyft Driver.jpg`: the grey rectangular overlay
  mask returned around the resting bubble.
- `Screenshot_20260814_155651.jpg`: accepting the newer Uber `$19.94 / 22.4 km`
  offer also left the earlier `$5.36 / 4.8 km` offer marked Accepted.

Root-cause audit and local fixes:

1. Multiple apps increase Android window/surface transitions, but are not the
   mask's root cause. The overlay still used a `FlutterTextureView`; three prior
   fixes only reasserted `setOpaque(false)` before/after layout changes. Samsung
   can replace that `SurfaceTexture` asynchronously, which exposes the grey
   overlay-window rectangle. The local service now uses Flutter's supported
   transparent `SurfaceView` (`TransparencyMode.transparent`) and removes the
   delayed opacity retries. Window size, drag, touch bounds, and pill placement
   remain unchanged.
2. Accepted-trip frames repeat. Each repeat called "mark newest unresolved
   Uber offer", so the first event marked `$19.94` and the next walked backward
   to `$5.36`. Outcome inference is now bound to the exact logged candidate;
   repeated Accepted or browse frames are idempotent and cannot alter an older
   offer.
3. The status pill on each History card is now editable: Accepted, Not taken,
   or Unconfirmed. Manual corrections persist and automatic inference cannot
   overwrite them.
4. Rules now has an independent **Voice verdict** toggle and preview. It speaks
   only newly logged GOOD offers using Android's system voice; every new alert
   replaces speech still playing, so bursts cannot build a queue. Settings now
   offers USD, CAD, AUD, NZD, MXN, and BRL labels without FX conversion. A new
   install seeds the label and conventional distance unit from Google Play's
   billing country; saved driver choices are never overwritten.

Focused regression checks were added in `test/offer_watcher_test.dart`,
`test/offer_log_dedupe_test.dart`, `test/history_filter_test.dart`,
`test/settings_hydration_test.dart`, and `test/settings_screen_test.dart`. The
native overlay class compiles against Android 36, Flutter, and AndroidX. The
complete preflight subsequently passed in the normal WSL shell before build 32.

## User-observed runtime behavior

The evidence is in:

`C:\Users\vamsi\Downloads\fox\Aug 14`

- `Screenshot_20260814_144005_Lyft Driver.jpg`
- `Screen_Recording_20260814_143958_Lyft Driver.mp4`
- `Screen_Recording_20260814_144229_Hopp Driver.mp4`

Cards visible in the evidence:

- Lyft: `$3.96 Incl. CA$1 bonus`, `$29.70/hr`, `3 mins · 0.4 km`,
  `5 mins · 1.5 km`, `Accept`.
- Hopp: `$4.40 (NET, tax included)`, `8 min • 3.1 km`,
  `6 min • 2.7 km`, `Match`.

Observed symptoms before the latest changes:

- Uber produced a verdict, but felt slow.
- Lyft produced inconsistent/changing verdict behavior.
- Hopp produced no verdict during a long-lived card.
- The FoxyCo bubble visibly flickered during OCR.
- Platform transitions could briefly return to the bubble or clear a newer pill.

The recordings were made with **Force OCR test mode** likely enabled. That mode
deliberately bypasses readable Accessibility text, so its latency is not the
normal Accessibility-first production latency.

## Root causes identified

1. The native OCR path hid and restored the whole FoxyCo overlay around every
   screenshot. With a 1.5-second OCR cooldown, that created the visible flicker.
2. ML Kit can omit the tiny `·`, `•`, or `-` glyph between time and distance.
   Hopp/Lyft lines such as `8 min 3.1 km` then failed the strict leg expression.
3. OCR output had no platform identity and was tried against parsers in registry
   order. A stacked or partially visible screen could therefore be attributed
   to the wrong platform.
4. `OverlayService.clearPill()` sent a second delayed clear. That delayed message
   could arrive after the next platform's offer payload and erase the new pill.
5. A valid platform switch cleared the old pill before showing the newly parsed
   offer, forcing a visible pill → bubble → pill transition.

## Latest implementation changes

### OCR capture

- `AccessibilityService.takeScreenshot` remains the capture mechanism on
  Android 11+; there is no MediaProjection session or screen-sharing prompt.
- The visible overlay is no longer hidden or resized for capture.
- The screenshot is copied to a mutable in-memory bitmap.
- FoxyCo's current overlay rectangle is cleared only in that bitmap before ML
  Kit receives it.
- Pixels are wiped/recycled after recognition and are never persisted.

Relevant files:

- `third_party/flutter_accessibility_service/android/src/main/java/slayer/accessibility/service/flutter_accessibility_service/AccessibilityListener.java`
- `third_party/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java`

### Parser and platform routing

- The time/distance separator is optional, while minutes, numeric distance, and
  a valid distance unit remain mandatory.
- OCR capture requests retain the watched package that triggered the screenshot.
- OCR results are parsed only by that package's parser, rather than by every
  supported parser.
- A valid active offer from a different platform replaces the current payload
  directly. A platform switch clears only when the new active frame is not a
  valid offer.

Relevant files:

- `lib/parser/offer_parser.dart`
- `lib/parser/parser_registry.dart`
- `lib/services/accessibility/offer_watcher.dart`

### Overlay message ordering

- A newly created overlay waits once for its isolate listener, clears stale
  state, and then accepts later offer payloads.
- Offer payloads and pill clears are each sent once.
- The old delayed duplicate clear was removed.

Relevant files:

- `lib/services/overlay_service.dart`
- `lib/ui/overlay/overlay_entry.dart`

## Regression coverage added

- Exact Hopp OCR fixture without a separator.
- Exact Lyft OCR fixture without a separator.
- OCR result remains bound to the triggering platform.
- A valid top offer replaces another platform without an intermediate clear.
- Existing Accessibility-success path still avoids OCR.
- OCR remains rate-limited/non-overlapping.

Relevant tests:

- `test/parser/hopp_parser_test.dart`
- `test/parser/lyft_parser_test.dart`
- `test/offer_watcher_test.dart`

## Verification completed here

- Both modified Java classes compile independently against the project's
  Android, Flutter, AndroidX, and ML Kit classpaths.
- The exact Aug 14 Lyft and Hopp OCR lines pass a direct assertion-based Dart
  smoke check.
- `dart format` reports the touched Dart files already formatted.
- `git diff --check` reports no whitespace errors.
- The normal WSL release preflight passed analysis, all Flutter tests, and
  Firestore rules tests; build 32 then completed successfully.

Earlier sandbox-only Flutter attempts were blocked by its read-only SDK and
localhost restrictions; the later normal-WSL preflight supersedes that limitation.

## Validation still required

Automated release validation is green. Remaining work is Play/device testing:

1. Upload `dist/FoxyCo-v1.0.9+32-release-20260815-0057.aab`.
2. Install build 32 from the Play testing track, not from a locally built APK.
3. For the Play-country default check, uninstall/clear FoxyCo data first so no
   saved currency exists; confirm Settings selects the storefront currency.
4. Complete production Pass 1 and the M15.11–M15.17 rows in
   `docs/MANUAL_TESTS.md`.
5. Run forced-OCR Pass 2 later with a debug APK; the Force OCR switch is
   intentionally absent from release builds.

Optional debug-only install for forced-OCR testing (not the Play-country test):

```powershell
$adb="$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$device="192.168.2.10:39941"
& $adb -s $device install -r "$env:USERPROFILE\Downloads\foxyco-debug.apk"
& $adb -s $device logcat -c
```

After either install, toggle the FoxyCo Accessibility service off and on once
so the newly installed native service is definitely connected.

## Device test order

### Pass 1 — production behavior

1. Pixel Capture: **ON**.
2. Force OCR test mode: **OFF**.
3. Start monitoring.
4. Present one readable offer each from Uber, Lyft, and Hopp.
5. Confirm Accessibility produces fast verdicts and OCR runs only for an
   empty/incomplete Accessibility frame.
6. Present offers from multiple apps. Confirm the top active card owns the
   verdict and a valid next card replaces it without an intermediate bubble.
7. Confirm no repeated voice announcement or duplicate History row for one card.

### Pass 2 — forced OCR behavior

1. Keep Pixel Capture **ON**.
2. Enable **Force OCR test mode** in the debug APK.
3. Repeat the exact Lyft and Hopp cards if possible.
4. Confirm there is no visible overlay flicker during capture.
5. Expect OCR to be slower than Pass 1; this mode intentionally bypasses
   readable Accessibility text.

Capture the resulting log:

```powershell
& $adb -s $device logcat -d -v threadtime |
  Out-File "$env:USERPROFILE\Downloads\foxyco-aug14-runtime.txt" -Encoding utf8
```

If the wireless-debugging port changes, replace `39941` with the current
**IP address & port** shown under the device's Wireless debugging screen. Do not
use the separate pairing port for `adb connect` or `-s`.

## What to inspect if a card still misses

Use the app Logs screen or logcat. Production diagnostics intentionally avoid
raw rider names and addresses. Look for:

- `source=accessibility` versus `source=ocr`.
- `recognized N lines`.
- `MISS card-like frame ... payout=... legs=...`.
- The package name that triggered the read.
- Whether one History row or multiple rows were created.

Interpretation:

- `payout=true, legs=0`: OCR formatting still differs from the known card;
  inspect sanitized shape first, then collect a consented screenshot/log.
- Correct fields but wrong platform: verify the active event's package and the
  stacked-window order; do not restore the removed global parser loop.
- Correct first verdict followed by an unexpected clear: inspect message order;
  do not restore delayed duplicate `clearPill` sends.
- No OCR log with Force OCR mode enabled: confirm the active package is one of
  `com.ubercab.driver`, `com.lyft.android.driver`, or `ee.hopp.driver` and that
  Pixel Capture is still enabled.

## Worktree caution

The worktree contains a large, intentional set of uncommitted changes from the
Rules navigation work, OCR implementation, legal disclosures, parser/history
improvements, and Settings fixes. Do not reset, checkout, or bulk-revert it.
Review changes by subsystem and preserve all unrelated user work.

Build code 31 is already consumed in Play Console. Build 32 exists locally and
was not confirmed uploaded when this handoff was updated.

## Pending after build-32 validation

Release-critical development still identified by the current product scope:

1. Parse and retain each offer's actual currency/locale rather than relying on
   the driver's global display label; continue to perform no FX conversion.
2. Snapshot the active scoring rules on each History record so later Rules
   edits cannot change an old offer's explanation.
3. Finish battery/ANR/process-restart testing and signed Play billing/trial,
   accessibility declaration, and closed-test gates.

Only after those: DoorDash, Spark, Instacart, and Grubhub one at a time, then
optional vehicle-cost/profit features. Bubble-position persistence, chime,
mileage, expenses, heatmaps, AI insights, goals, and cloud backup remain deferred.
