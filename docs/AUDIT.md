# Release audit

Audit date: 2026-09-28

Candidate: `1.0.16+114`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

## Build 114 — new Play upload version

Build 113 was already uploaded to Play Console. Build 114 increments both
version name and version code to `1.0.16+114`; app behavior is unchanged.
The guarded release helper passed Flutter analysis, the full Flutter test suite,
and Firestore rules tests. The generated AAB's JAR signature verified.

Verified artifact: `FoxyCo-v1.0.16+114-release-20260928-0121.aab`

SHA-256: `34c1fdefc0f6e4bee64cf99185a933616e00e13503e83b1bd121afeadf3d1607`

## Build 113 changes

- Home replaces the Review Inbox backlog card with a compact full-day Session
  recap. Multiple shifts on one date combine their active duration and earnings;
  the two most recent earlier workdays are available under Recent sessions.
- History session rows gain a floating return-to-top control, and payout amounts
  use the FoxyCo orange accent.
- Garage places a premium income-versus-expenses report below Vehicles. Monthly,
  quarterly, and yearly views navigate with arrows or graph swipes and show
  animated income/expense lines, payout breakdown, ledger expenses, balance,
  and category totals.
- Report income reuses History's recorded payout rollup, including final
  cancellation fees and toll reimbursements once. Expenses come from editable
  Garage ledger entries. Report balance is not a tax calculation.
- The vehicle-expense editor keeps Save visible above the keyboard.

## Build 113 verification

- Flutter analysis: passed
- Full Flutter test suite: passed
- Firestore rules tests: passed
- Signed AAB built with the guarded release helper and Play licensing key
- JAR signature verification: passed (self-signed upload certificate)
- Device checks R113.1–R113.9: pending; see `MANUAL_TESTS.md`

Verified artifact: `FoxyCo-v1.0.15+113-release-20260928-0114.aab`

SHA-256: `be32be3c140330668dbe08f4075b7e989810c245548b535a1e9e7d3666ed3e50`

The checks above establish a signed bundle and host-side behavior only. Play
acceptance, device behavior, and rollout remain external release gates.

## Build 111 changes

- Manual final-payout and cancellation-fee corrections now refresh History
  totals, saved session summaries, and Home goal progress from one shared
  rollup. Cancelled offers contribute no accepted count, route distance/time,
  or trip performance rate.
- History separates confirmed final money from accepted-offer estimates; the
  goal card links to its contributing calendar-period rows.
- First-run onboarding shows the real verdict pill before permissions, and
  lifetime-account sign-in copy no longer refers to protecting a trial.
- A Google Maps OCR capture context now recreates only Flutter's child surface,
  automating the part of stop/start Watching that cleared the S24 Ultra grey
  mask while preserving the service and shift. Other app switches remain
  diagnostic-only. Q.24 remains a physical-device gate before this recovery is
  claimed verified.

## Build 110 changes

- Week, Month, Quarter, and Year earnings targets are editable from the Home
  goal card and persist with the driver's existing settings.
- Large goal and progress amounts scale to narrow cards instead of clipping.
- Focused tests cover editing, serialization, and narrow-screen layout.

## Build 109 changes

- Lyft and Hopp duration parsing now includes an optional hour component, so
  `1 hr 28 mins` is 88 minutes rather than 28.
- History can add a missed completed Uber, Lyft, or Hopp ride with validated
  payout, distance, duration, and past timestamp; the current rideshare rules
  produce its stored verdict.
- Home now shows an animated goal card after Last session. Week, Month,
  Quarter, and Year progress uses taken/completed History earnings and excludes
  missed offers.
- Startup uses the supplied fox-car artwork and rotates Mountains → Snow →
  Autumn in one bounded native Flutter animation, with a reduced-motion path.
- Parser, persistence, narrow-layout, Home integration, seasonal rotation, and
  goal-period regression coverage were added.
- Vendored overlay/accessibility modules now declare the app's minSdk 26, and
  the API 30 OCR path carries its existing runtime gate into release lint.
- The S24 Ultra grey mask is not claimed fixed. Build 108 diagnostics and Q.24
  remain the evidence path; stop/start Watching remains the known workaround.

## Build 108 changes

- No layout, animation, parser, scoring, or outcome-rule changes from build 107.
- Expanded native window/surface and sampled OCR handoff diagnostics, including
  device/Android version and bounded alpha-only sampling of our own 2x2 corner.
- Native OCR failures/timeouts and card-shape counts are distinguishable;
  stale Dart OCR logs explain generation invalidation and synthetic no-card
  results without recording raw text.
- Regression checks cover stale-result reasons and no-card labeling.
- User confirmed the intermittent S24 Ultra mask appears immediately when
  selecting external Google Maps inside Lyft. Restarting Watching clears it.
  The supplied logs do not prove the root cause; build 108 is diagnostic,
  not a verified mask or stacked-Radar fix. Q.24 remains a device gate.

## Build 107 changes

- Total distance, total time, pickup, and ride icons now share the exact
  vertical centerline of their values.
- The distance-edit button is overlaid at the cell edge, preserving its full
  tap target without pushing the route value or label out of alignment.
- Widget coverage measures all four icon/value pairs and protects the compact
  sheet at normal, short, and large-text layouts.
- Version, About, testing, and release documentation are synchronized to build
  107.

## Build 106 changes

- Unmarked saved final payouts add their separately stored tip once while
  loading. New and rewritten rows persist an inclusion marker so restart,
  backup, and import cannot add it again.
- The reported Lyft example now resolves `CA$50.44 + CA$2.00 tip` to
  `CA$52.44` received and `CA$28.88` performance earnings after its
  `CA$23.56` toll reimbursement.
- Version, About, architecture, offer-detection, testing, and release
  documentation are synchronized to build 106.

## Build 105 changes

- Final payout editing adds a separately entered tip exactly once, keeps toll
  reimbursement separate from performance earnings, and exposes the net fare
  on compact History cards.
- Bonus and tip share one compact detail row, toll wording is shorter, long
  values fit without clipping, and distance editing uses an inline icon.
- Screenshot bitmap copying and clearing run outside the Android UI thread;
  routine no-card OCR diagnostics are sampled without changing capture cadence,
  parsing, retries, or offer delivery.
- Version, About, architecture, offer-detection, testing, and release
  documentation are synchronized to build 105.

## Build 104 changes

- Lower Lyft offers are cached even when Uber wins the overlay race, so the
  Lyft verdict returns after the covering Uber card closes.
- History counts and distance-editor guidance fit without clipping, and a
  successful feedback handoff clears the submitted form.
- Final earnings can record included tips and toll reimbursements; tolls stay
  visible in History but are excluded from performance rates.
- Session and trip hourly rates are labeled by their actual time basis.
- Version and release documentation are synchronized to build 104.

## Build 103 changes

- Active-trip evidence now survives offer and partial frames until the driver
  app positively returns to browse/home, preventing a covered offer from being
  falsely marked Accepted when the original trip screen returns.
- Diagnostic-only route matching compares pending offer locations with later
  accepted-trip screens in memory. Logs contain opaque session fingerprints,
  counts, scores, and uniqueness only; History and outcome inference are not
  changed by the shadow result.
- Version and release documentation are synchronized to build 103.

## Build 101 changes

- Cross-app Uber probing is explicitly verified over every supported selected
  non-Uber app: Hopp, Lyft, DoorDash, Instacart, and Skip.
- Any platform's saved History distance can be corrected without deleting the
  row; rates, session summaries, and the snapshot-based verdict refresh.
- Privacy-safe native mask diagnostics now reach copied in-app Diagnostics as
  well as ADB logcat.
- Version and release documentation are synchronized to build 101.

## Build 100 changes

- Every active selected Lyft/Hopp frame makes a rate-limited, bounded Uber OCR
  probe, so a stacked Uber card is found even over a plain lower-app map.
- Lower-app partial/map frames cannot clear or replace a confirmed Uber OCR
  card; OCR alone owns that top card until it disappears.
- Lyft selects the live card's lower payout instead of its persistent top
  earnings balance, preventing GOOD → OK voice/pill changes.
- Uber OCR rejects dropped distance decimals such as `30.4` → `304 km` before
  scoring or history persistence.
- Overlay health loss recovers the native window without ending the shift;
  native generation and surface lifecycle diagnostics were expanded.
- Overlay buffers explicitly require RGBA alpha, and detail-band icons align
  at the left edge of each half.
- Version and release documentation were synchronized to build 100.

## Verification

- Flutter analysis: passed
- Full Flutter suite: passed
- Focused parser/watcher/dashboard regression suites: passed
- Native Android overlay/OCR compilation: passed
- Android release lint: passed
- Signed release bundle and checksum verification: passed
- Packaged version and About label synchronized to build `111`: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.14+111-release-20260920-2241.aab`

SHA-256: `3b5e62cb5fd1b683521ce47c22b17467b868119ce95d73112f58df2a6534b1c0`

Jarsigner reports `jar verified` with self-signed upload-certificate,
no-timestamp, and streaming ZIP manifest-order warnings. Android bundle
validation is checked separately; Play acceptance and device testing remain
external gates, not claims made by host checks.

## Device gates

- Reproduce every selected non-Uber app → Uber → lower-offer restoration with real cards.
- Confirm `$28.41` never stores `304 km` and the corrected OCR stores `30.4 km`.
- Confirm Lyft's `$44.83` earnings balance never becomes an offer payout.
- Verify stale Uber cards clear promptly and never create duplicate History.
- Switch from Uber/Lyft to Google Maps and confirm the bubble stays transparent.
- Show a new request over an active trip and confirm its outcome stays unknown.
- Install from the Play test track and verify sign-in, purchase, restore,
  refund/revoke, update flow, crash/ANR, and battery behavior.

Do not retain rider names, addresses, screenshots, or raw Accessibility/OCR
text as release evidence.
