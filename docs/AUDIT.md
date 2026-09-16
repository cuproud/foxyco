# Release audit

Audit date: 2026-09-01

Candidate: `1.0.14+107`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

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
- Signed release bundle and checksum verification: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.14+107-release-20260901-2122.aab`

SHA-256: `b99855cc52f446ecf447c6e18cb66fb434a8ae5c04d5348a355a5501ee1b8852`

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
