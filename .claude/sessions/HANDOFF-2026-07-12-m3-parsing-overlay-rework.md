# HANDOFF — M3 parsing + overlay rework (2026-07-12)

**Read this first, then `docs/ROADMAP.md` M3 + `.claude/completions/2026-07-12-m3-offer-parser.md`.**

## Where we are
M3 (real offer reading) is WIRED and the pipeline runs on device
(accessibility → parser → engine → overlay pill). Hopp + Lyft + Uber all
detected at least once on a real Galaxy S24 (Android 16, `com.foxyco.app`, debug
build, wireless adb `192.168.2.10:<port>` — port rotates, reconnect each time).

BUT device testing exposed many correctness + UX bugs. User rated it **10/100**
and wants a **robust, guideline-driven rewrite of parsing + overlay behavior —
NOT trial-and-error patching.** That is the whole job for next session.

## CONFIRMED FACTS (don't re-derive)
- Real package names (verified via `pm list packages`):
  - Uber Driver = `com.ubercab.driver`
  - Hopp Driver = `ee.hopp.driver`  (Estonian, `.ee` — was the original "no Hopp" bug, now fixed)
  - Lyft Driver = `com.lyft.android.driver`
- These are set in `lib/parser/parser_registry.dart` AND
  `android/app/src/main/res/xml/accessibilityservice.xml` (must stay in sync).
- Accessibility permission is a SIDELOADED-APP problem: Android 13+ "Restricted
  Settings" greys out the toggle. Fix on phone: Settings→Apps→FoxyCo→⋮→"Allow
  restricted settings", or `adb shell appops set com.foxyco.app ACCESS_RESTRICTED_SETTINGS allow`.
- Node text arrives partly wrapped as `{mSpanCount:… mText: <real text>}` — the
  watcher unwraps `mText:` (lib/services/accessibility/accessibility_watcher.dart).
- Our $/km + $/hr MATH is correct — verified against Maxymo's and Lyft's own
  printed numbers on multiple offers. The bugs are in WHAT we parse, not the math.

## REAL OFFER FORMATS (from references/bug1 (1..8).jpg — captured on device)
- **Uber** offer card: `$4.99` big → `2 mins (0.6 km) away` → `9 mins (3.7 km) trip`,
  has "Accept". (bug1 (3),(4)). Format matches our regex — yet user said "Uber
  didn't detect one ride". MUST capture real Uber accessibility nodes to see why
  (likely text split across nodes / different a11y labels than visual text).
- **Hopp** offer card: `$7.68 (NET, tax included)` → `1 min • 0.5 km` (pickup) →
  `12 min • 8.4 km` (dropoff), has "Accept"/"Match". (bug1 (2),(5)).
- **Lyft** offer card: `$10.05` → `$30.15/hr est. rate` → `3 mins • 0.6 km` →
  `17 mins • 11.2 km`, has "Accept" + person name + "Lyft". (bug1 (1)).

## BUGS (evidence-based, from the 8 bug images)

### Parsing — the pill shows garbage over non-offer screens
1. **bug1 (5):** real Hopp offer `$9.42 / 17.9 km` on screen, but pill showed
   **`GOOD $12 · $1.43/km · $30/hr`** = the FAKE SAMPLE (`_samples[0]` in
   overlay_controller). Stale/simulated data leaked over a real different offer.
2. **bug1 (6):** Lyft "Ride Finder" browse map (no offer), pill stuck showing
   old `BAD $11.26 · $0.25/km · $17/hr` (scheduled-ride garbage).
3. **bug1 (8):** Lyft browse map — pill parsed **`$37.64`** (the Turbo/streak
   banner at top) as payout → `BAD $37 · $0.82/km · $57/hr`. Grabbed a header
   number + mashed map-bubble distances.
4. **Lyft scheduled-rides** on home screen were parsed as offers (mixing 2
   rides into one fake offer, e.g. 45.3 km). Partial guard added
   (lib/parser/lyft_parser.dart `_notAnOffer`, legs != 2) but NOT robust enough.
5. **407 toll:** Hopp shows `Toll Fee • $2.10` ABOVE payout; naive first-$ took
   the toll. Fix added (ParserPatterns.findPayout skips toll/fee/tip/bonus/rate)
   but needs hardening + real-node verification.

**ROOT CAUSE:** parsers run on EVERY screen and try hard to find numbers. Need a
strict "is this actually an offer card?" gate BEFORE parsing (presence of
Accept/Match button + payout + exactly-2 pickup/dropoff legs, and a per-platform
positive signature), else return null. Guardrails > cleverness.

### Overlay / pill behavior (user's exact requirements)
6. **Pill must track the CURRENT card live.** 12s timeout is WRONG. If user
   rejects an offer and a new one appears in 1-2s, pill must instantly show the
   NEW offer; if the offer card closes, pill must close SIMULTANEOUSLY. Drive
   pill visibility from "is an offer card currently on screen", not a timer.
7. **Stale pill:** pill showing an old offer over a new/absent card (bugs 1-3).
   Same fix as #6 — clear the moment the offer screen is gone.
8. **Drag bounds broken:** bubble/pill drags OFF-screen, only ~5% visible, can't
   drag back (bug1 (7): "OVERFLOWED BY 24" debug text visible). Need: draggable
   left↔right to the EDGES only, never off-screen or "deep inside" — clamp X so
   the whole pill stays on-screen; vertical stays in a safe band.
9. **Tap bubble → open FoxyCo app directly.** Currently tapping contracts pill→
   bubble, and tapping bubble does NOT foreground the app (can't get back to
   FoxyCo). Must launch/bring the host app to front from the overlay isolate.
10. **Drag bubble to bottom = close bubble AND stop watching (kill overlay +
    set app to inactive).** Currently native drop-to-dismiss closes the bubble
    but the app still shows "active" — state desyncs. Bubble drop must propagate
    "stopped watching" to the dashboard.
11. **Active/Pause toggle in-app does NOT show the bubble.** Bubble only appears
    via the fake "Simulate offer" button. Turning watching ON should bring the
    overlay up; pause should dim/hide appropriately. Wire startWatching() to the
    watch status, not to the debug button.
12. **Flickering** still happens intermittently — partly fixed via dedupe
    (offer_watcher `_shownKey`) but tied to #6/#7 redesign.

## WHAT WAS ALREADY CHANGED THIS SESSION (in working tree, uncommitted)
- Hopp package fixed to `ee.hopp.driver`; Lyft added end-to-end (parser,
  registry, res/xml scope, platform enum, dashboard activePlatforms, strings.xml).
- `ParserPatterns.findPayout` (skips toll/fee/tip/bonus/rate lines) — parsers use it.
- `ParserPatterns.leg` shared regex; watcher `_unwrap` for `{…mText:…}` nodes.
- Lyft `_notAnOffer` guard + legs must == 2.
- offer_watcher `_shownKey` flicker dedupe + trace logging of every read/drop.
- Tests: 55 green (parser fixtures incl. toll regression + Lyft scheduled-screen
  rejection; offer_watcher pipeline incl. flicker guard). `flutter test` passes,
  `flutter build apk --debug` builds, release manifest has NO INTERNET (AUDIT #5).
- These are GOOD foundations but insufficient — the rewrite should build on them.

## NEXT SESSION — recommended plan
1. **Capture ground-truth nodes first.** Reconnect adb, run the debug logcat
   (app logs `FoxyCo[watch] read pkg=… :: <joined nodes>` for every screen).
   Trigger a real Uber offer, a real Hopp offer, a real Lyft offer, AND each
   app's browse/home screen. Save the exact node dumps → these become the
   fixtures. This is why Uber "didn't detect" — verify its real nodes, don't guess.
   Monitor cmd: `adb logcat -v tag | grep --line-buffered "FoxyCo\[watch\]"`
2. **Design a strict offer-detection contract** (per platform): positive
   signature (has Accept/Match + payout + exactly 2 legs + platform marker) →
   Offer; anything else → null. Write it as explicit guardrails with the captured
   fixtures as tests BEFORE touching device again.
3. **Redesign overlay lifecycle** around "current offer on screen" (reqs 6-12):
   - pill visibility = offer-present, not a timer; clear instantly on offer gone.
   - clamp drag X so full pill stays on-screen (fix native onTouch in
     third_party/flutter_overlay_window OverlayService.java + the moveOverlay path).
   - bubble tap → foreground host app (native Intent, launchable when backgrounded).
   - bubble drop-to-bottom → close overlay AND set dashboard inactive (propagate
     an action to main isolate).
   - watch status ON → startWatching() shows bubble; OFF → hide. Decouple from
     the Simulate debug button (that button can stay only as a dev tool).
4. Keep it test-first and guardrailed. User explicitly does not want
   trial-and-error. Verify each fix on device via logcat before moving on.

## Key files
- Parsers: lib/parser/{offer_parser,uber_parser,hopp_parser,lyft_parser,parser_registry}.dart
- Pipeline: lib/services/accessibility/{accessibility_watcher,offer_watcher}.dart
- Overlay: lib/services/overlay_service.dart, lib/ui/overlay/{overlay_entry,overlay_controller,verdict_pill,fox_bubble}.dart
- Native: third_party/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/{OverlayService,FlutterOverlayWindowPlugin}.java
- Main/wiring: lib/main.dart, lib/ui/home/{dashboard_controller,home_screen}.dart
- Native a11y config: android/app/src/main/res/xml/accessibilityservice.xml, res/values/strings.xml
- Evidence: references/bug1 (1..8).jpg  (analyzed above)
- Tests: test/parser/*, test/offer_watcher_test.dart

## Device / tooling
- flutter at /home/vamsi/development/flutter/bin/flutter (3.44.4, Dart 3.12.2)
- adb at /home/vamsi/android-sdk/platform-tools/adb
- Build+install: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- Reconnect: `adb connect 192.168.2.10:<port>` (get current port from phone:
  Settings→Developer options→Wireless debugging). Was refused at handoff time —
  phone likely rotated port / dropped.

## NOT in scope yet (M4/M5, deferred)
Drift DB, real Home tally/last-offer (still mock), onboarding, removing Simulate
card, stripping debugPrint('FoxyCo[overlay]…') markers. M2 vendored fork
drop-to-dismiss verification (MANUAL_TESTS 2.10/2.14) overlaps with req #10.

## Nothing committed. All M2 + M3 changes live together in the working tree.
