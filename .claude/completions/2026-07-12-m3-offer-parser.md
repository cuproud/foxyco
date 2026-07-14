# 2026-07-12 - M3: read real Uber/Hopp offers automatically (+ $/hr pill)

## State: code-complete, tests green, debug APK builds - device verify pending

The overlay pill ("bubble review") was driven only by the Simulate button. M3
replaces that fake with the real pipeline, so a live Uber/Hopp offer draws the
pill with no manual tap - the thing references/new (2).jpg (Maxymo) shows.

Pipeline: AccessibilityWatcher -> ParserRegistry -> Uber/HoppParser -> Offer
-> DecisionEngine.evaluateOffer(thresholds) -> Verdict
-> OverlayController.showFromOffer -> pill

## What landed

Domain
- domain/offer.dart - parse-time model: payout, pickup/dropoff km + minutes,
  payIsNet, rawText. Getters totalKm, totalMinutes, pricePerKm, pricePerHour.
- domain/decision_engine.dart - added evaluateOffer(Offer, Thresholds) (thin
  delegate; existing evaluate(double,..) untouched, tests intact).

Parser (parser/, pure Dart)
- offer_parser.dart - OfferParser interface (parse -> Offer?, null = fail safe),
  shared payout regex, tunedAgainst version tag.
- uber_parser.dart - anchors "N mins (X km) away|trip", gross pay, pickup optional.
- hopp_parser.dart - two "N min . X km" legs ordered by timeline (first=pickup),
  NET flag -> payIsNet. Tolerates middot/bullet/hyphen separators.
- parser_registry.dart - dispatch by foreground package.

Services
- services/accessibility/accessibility_watcher.dart - wraps
  flutter_accessibility_service (^1.2.0). Flattens node tree -> ScreenRead,
  debounced 250ms + deduped (AUDIT #4). Permission + status-change helpers.
- services/accessibility/offer_watcher.dart - the pipeline Notifier. Gated on
  WatchStatus.watching; unhandled package / low-confidence parse / unknown
  verdict all no-op.

UI wiring
- overlay_controller.dart - showFromOffer(offer, verdict) maps -> payload
  (carries totalMinutes). Debug samples now include minutes.
- overlay_payload.dart + verdict_pill.dart - payload gains totalMinutes /
  pricePerHour; pill line is now "$pay . $X.XX/km . $Y/hr" (Maxymo-style);
  $/hr hidden when no time parsed. Pill window widened 300->360 dp.
- dashboard_controller.dart - refreshPermissions() (real overlay + a11y state ->
  watching/paused/blocked) and requestMissingPermissions(). Off-device the
  channels throw -> swallowed, mock state kept (widget tests unaffected).
- main.dart - FoxyCoApp now ConsumerStatefulWidget: post-frame boots overlay +
  offer watcher + refreshPermissions; lifecycle-resume re-checks grants.
- home_screen.dart - "Fix permissions" button wired to the request flow.

Native (Android)
- Manifest: registered plugin AccessibilityListener service.
- res/xml/accessibilityservice.xml - scoped to com.ubercab.driver,com.hopp.driver,
  read-only, description string (Play disclosure, AUDIT #1).
- res/values/strings.xml - the honest accessibility rationale.

## Verified (off-device)
- flutter analyze - no issues.
- flutter test - 47 pass. New: uber/hopp fixture tests (reference-layout node
  dumps, boundaries, null cases) + offer_watcher_test (parse->score->pill, pause
  gating, unhandled-package drop) + payload $/hr round-trip.
- flutter build apk --debug - builds with the plugin.
- Merged manifest privacy check (AUDIT #5): release manifest has NO INTERNET;
  a11y service present. (Debug manifest's INTERNET is Flutter's hot-reload
  injection - debug-only, doesn't ship.)

## Two things needing YOUR device (can't be done off-device)
1. com.hopp.driver is a PLACEHOLDER. Confirm the real foreground package during a
   Hopp offer; fix ParserRegistry.hoppPackage AND res/xml together if wrong.
2. Live parse verification - run MANUAL_TESTS rows 3.1-3.8. The regexes are tuned
   to the reference screenshots; real accessibility node text can differ (a11y
   labels vs visual text). Rows 3.3/3.4 may need selector tuning - the debug
   print "FoxyCo[watch] ... -> Verdict" shows what parsed.

## Not in scope (deferred, per agreed plan)
- M4: Drift DB, real Home tally/last-offer (still mock), standalone onboarding,
  removing the Simulate debug card.
- Also still open from M2: vendored overlay fork drop-to-dismiss (MANUAL_TESTS
  2.10/2.14), strip debugPrint('FoxyCo[overlay]...') markers before release.

## Nothing committed - all M3 changes are in the working tree alongside M2's.
