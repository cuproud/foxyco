# Release audit

Audit date: 2026-08-29

Candidate: `1.0.13+101`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

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

Verified Play artifact: `FoxyCo-v1.0.13+101-release-20260829-2159.aab`

SHA-256: `9c6b9899d2847608b4f9a0e1f2dc02545b82c181e053cf6b715fadb1d8adc8a1`

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
