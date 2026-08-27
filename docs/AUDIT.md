# Release audit

Audit date: 2026-08-27

Candidate: `1.0.11+97`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

## Build 97 changes

- Native OCR now returns one spatially bounded Uber card instead of flattening
  every visible app into one text list.
- Dart applies the same Uber-card boundary before parsing as defense in depth.
- Dropped payout decimals are rejected and retried before scoring or History.
- A Lyft/Hopp offer covered by Uber is retained and restored for a fresh five
  seconds when Uber closes.
- Version and release documentation are synchronized to build 97.

## Verification

- Flutter analysis: passed
- Full Flutter suite: passed
- Focused parser/watcher suite: 100 tests passed
- Native Android OCR compilation: passed
- Signed release bundle and checksum verification: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.11+97-release-20260827-1126.aab`

SHA-256: `c8460b9ecf2a6c378cc72b615dbc3ad406c397c08d10387a06876a380ada3df4`

## Device gates

- Reproduce Lyft/Hopp → Uber → lower-offer restoration with real cards.
- Confirm the video example resolves to `$7.48`, `9.7 km`, and `$20.40/hr`.
- Verify stale Uber cards clear promptly and never create duplicate History.
- Install from the Play test track and verify sign-in, purchase, restore,
  refund/revoke, update flow, crash/ANR, and battery behavior.

Do not retain rider names, addresses, screenshots, or raw Accessibility/OCR
text as release evidence.
