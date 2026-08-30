# Release audit

Audit date: 2026-08-29

Candidate: `1.0.12+100`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

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
- Version and release documentation are synchronized to build 100.

## Verification

- Flutter analysis: passed
- Full Flutter suite: passed
- Focused parser/watcher/dashboard regression suites: passed
- Native Android overlay/OCR compilation: passed
- Signed release bundle and checksum verification: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.12+100-release-20260829-2056.aab`

SHA-256: `7521598110ae577705450b9be3efdd4a00bc8231313252d8a828ab9ab2f36d46`

## Device gates

- Reproduce plain Lyft/Hopp map → Uber → lower-offer restoration with real cards.
- Confirm `$28.41` never stores `304 km` and the corrected OCR stores `30.4 km`.
- Confirm Lyft's `$44.83` earnings balance never becomes an offer payout.
- Verify stale Uber cards clear promptly and never create duplicate History.
- Switch from Uber/Lyft to Google Maps and confirm the bubble stays transparent.
- Show a new request over an active trip and confirm its outcome stays unknown.
- Install from the Play test track and verify sign-in, purchase, restore,
  refund/revoke, update flow, crash/ANR, and battery behavior.

Do not retain rider names, addresses, screenshots, or raw Accessibility/OCR
text as release evidence.
