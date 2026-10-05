# Architecture

Updated 2026-10-04 for `1.0.19+125`.

## Boundaries

```text
Android Accessibility event
  ├─ Maps window state → overlay surface refresh only
  ├─ complete selected-app nodes → matching parser
  └─ incomplete Uber nodes or active selected lower app + OCR approved
       → one rate-limited in-memory screenshot → Uber parser
                                      ↓
                              DecisionEngine (pure Dart)
                                      ↓
                  overlay + local history + optional voice verdict
```

- `lib/domain/` contains models and scoring logic with no Flutter or plugin
  imports.
- `lib/parser/` contains conservative, platform-specific parsers and registry
  routing.
- `lib/services/accessibility/` owns capture, deduplication, stale-result
  rejection, outcome inference, logging, and the parse-to-verdict handoff.
- `lib/services/overlay_service.dart` and `lib/ui/overlay/` own the separate
  overlay isolate and its small serialized payload.
- `lib/ui/` contains screens and Riverpod controllers.
- `third_party/` contains the two intentionally vendored Android plugin forks.

## Offer routing

`docs/OFFER_DETECTION.md` is the canonical, code-mapped specification for
capture sources, every platform parser, Uber OCR, stacked cross-app offers,
verdict scoring, entitlement display, lifecycle, deduplication, and outcome
inference. It must be read before changing those areas and updated in the same
change whenever their behavior changes.

At the architecture level, Accessibility is primary, parsers fail closed, Uber
OCR is an on-device fallback for inaccessible/stacked cards, and only a complete
normalized `Offer` reaches the pure-Dart decision engine. Android copies and
clears screenshot bitmap data on a dedicated OCR worker; overlay redaction and
the single-request guard keep UI access serialized and recognition bounded.

## Persistence

SharedPreferences stores settings, garage/reminders, offer history, and session
summaries as version-tolerant JSON. An offer record preserves:

- captured payout, bonus, pickup/drop-off distance, duration, workload, app,
  category, queue state, verdict, timestamp, and scoring snapshot;
- detected outcome separately from a manual outcome correction; and
- original payout separately from a manually entered final payout, tip, and
  toll reimbursement.

Manual corrections win over later inference. A manually entered tip is added to
the final payout once; tip and toll remain tracked as components. Reimbursed
tolls are excluded from performance earnings and rates. History is capped and
retention can be configured. Android backup and data extraction are disabled.

History can also create a completed manual Uber, Lyft, or Hopp ride when live
capture missed it. The entry uses the supplied payout, total distance, total
minutes, and past timestamp, then applies the current rideshare scoring rules.

Final-payout JSON marks that its separately stored tip is already included.
Unmarked legacy rows add that tip once while loading, then serialize with the
marker so restart, backup, and import cannot add it again.

History hydration collapses the two known payout correction signatures: a
dropped payout decimal (`$7.54`/`$754`) and pickup distance misread as payout.
Live OCR also rejects dropped distance decimals such as `30.4`/`304 km` before
they can reach history. The corrected row drives tallies and analytics.

CSV history backup is versioned and locale-independent. Human-readable columns
are accompanied by authoritative per-row JSON, preserving every `OfferSummary`
field (including manual outcomes, final payouts, detected outcomes, and scoring
snapshots). Import validates the whole file, then atomically merges or replaces
history; merge never overwrites local manual corrections. Settings and session
summaries are intentionally outside this offer-history backup.

## Privacy and security

- Raw Accessibility text, OCR text, and screenshots are memory-only.
- The overlay rectangle is redacted before OCR; bitmap buffers are cleared.
- Diagnostic logs contain parser shapes, timings, package identity, and parsed
  economics, never raw text or screenshots.
- Feedback attachments are selected and sent only by the user through an email
  app; temporary files are constrained to the app cache.
- Firebase stores authentication/trial state only. Firestore rules are
  owner-scoped, server-stamped, write-once, and default-deny.
- Google Play handles card data. Purchase verification fails closed without
  the Play public key.
- No analytics or location collection exists.

The Accessibility service is read-only, package-scoped, and declares
`android:isAccessibilityTool="false"`. The permission still requires Google
Play's declaration, prominent disclosure, consent flow, and review video.

## Platform and UI

- Android 8.0+ (`minSdk 26`); Android-only because the overlay and cross-app
  reading model is not available on iOS.
- Flutter Material 3, Riverpod, and go_router.
- The startup scene rotates through mountain, snow, and autumn landscapes in
  one bounded animation. Reduced-motion devices show the final static scene.
- Home derives Week/Month/Quarter/Year goal progress from recorded History
  payouts. A final payout replaces its upfront offer; a cancelled ride adds
  only its entered cancellation fee. Missed offers and cancelled route
  distance/time never count. Each target is editable and links to the exact
  calendar-period History rows contributing to it.
- Home's Session recap groups finished sessions and manual jobs by local
  calendar day. It sums watch durations (breaks excluded), adds manual work
  outside saved sessions once, and keeps two previous workdays in a separate
  collapsed panel. The acceptance rate and offer-quality split use captured
  offers; jobs taken and earnings include manual work. History's captured-offer
  acceptance percentage uses the same denominator and labels mixed offers and
  manual jobs as records. Garage's Income chart rolls up History payouts by
  selected week, month, quarter, or year; expenses stay in the separate payout
  snapshot, and the displayed balance is not taxable profit.
- Garage's selected Aurora bar has seven scattered fixed reflections with mixed
  sizes, two four-point highlights, independent 1.8–2.8 second opacity/scale
  phases, a warm rim and glow, an inner glow, and a 2.5% lift. Selection effects
  cross-fade inside the rounded mask. A shared clock survives bar/period changes
  and parent rebuilds;
  CustomPainter repaints the effect without rebuilding the chart each frame.
  Reduced motion shows four still reflections.
- Garage vehicle cards reserve the heading for brand and model, put body type
  and the saved color below, and show plate/year as wrapping metadata chips.
  The active-vehicle heading uses the same brand/model name; stored vehicle
  fields and the full year-inclusive title used elsewhere are unchanged.
  The active card is first; additional cars are collapsed under Other vehicles.
  Selecting another car promotes it and closes that group. Add vehicle is a
  48 dp plus icon at the right of the heading, including when Garage is empty.
- System text scale plus the in-app text multiplier is capped at 2×; focused
  widget tests cover narrow screens, large text, scrollability, and overlay
  geometry.
- The overlay runs in its own isolate; only small serialized verdict payloads
  cross the boundary.
- Overlay health loss during app resume recreates the native window without
  ending the active shift; native surface lifecycle is logged without content.

## Verification rule

Every release candidate must pass Flutter analysis/tests, Firestore rules
tests, Android release lint, a signed release build, and the real-device matrix
in `MANUAL_TESTS.md`. Parser correctness and overlay behavior cannot be proven
by host tests alone.

## Startup splash (build 125)

`lib/ui/splash/splash_screen.dart` uses the supplied
`assets/branding/foxyco_golden_mountain_drive.png` composite artwork. Portrait
screens use centered cover cropping; wider/landscape screens contain the image
to preserve the baked-in logo and tagline. The old separate splash car is no
longer registered as a runtime asset; the existing wordmark remains used elsewhere.

A single controller drives a 2.5% push-in, 5 dp upward drift, gentle reveal and
one glint projected onto the artwork's logo bounds. The artwork is a stable
AnimatedBuilder child with a repaint boundary. Reduced motion shows an unmoving
image without the glint. Normal navigation uses `context.go('/')` after 1.8 s;
reduced motion uses a 450 ms timer, and a separate 2.6 s ceiling also works when
animation ticks are suspended. Timers are cancelled on disposal and navigation
checks mounted state. A route-local system-bar annotation uses transparent bars;
Home resumes the app's existing theme annotation after navigation.
