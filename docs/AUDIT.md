# Release audit

Audit date: 2026-08-28

Candidate: `1.0.11+99`

Automated checks pass. Play upload remains conditional on the device and
Console checks in `MANUAL_TESTS.md` and `PLAY_RELEASE.md`.

## Build 99 changes

- An active Lyft/Hopp offer now makes one bounded OCR probe so an Uber card
  drawn above it is detected even when Uber emits no Accessibility event.
- A confirmed Uber card keeps the existing lifecycle polling; an ordinary
  Lyft/Hopp card does not start a screenshot retry loop.
- Late OCR results are discarded after the driver switches to Gallery or any
  other unselected app.
- Offers drawn over an existing trip can no longer inherit its accepted state.
- The overlay reapplies transparency when Android recreates its child surface.
- Home has a reminder inbox; diagnostic mail uses the tester address; offer
  detail icons align with their values.
- Version and release documentation are synchronized to build 99.

## Verification

- Flutter analysis: passed
- Full Flutter suite: 546 tests passed
- Focused watcher suite: 85 tests passed
- Native Android OCR compilation: passed
- Signed release bundle and checksum verification: passed
- Firestore rules and guarded Play bundle preflight: passed

Verified Play artifact: `FoxyCo-v1.0.11+99-release-20260828-2056.aab`

SHA-256: `3a841c5a9bfa31c07fb611d84779a61a1523aca20f7199ccadd15981e8ae5b83`

## Device gates

- Reproduce Lyft/Hopp → Uber → lower-offer restoration with real cards.
- Confirm the video example resolves to `$7.48`, `9.7 km`, and `$20.40/hr`.
- Verify stale Uber cards clear promptly and never create duplicate History.
- Switch from Uber/Lyft to Google Maps and confirm the bubble stays transparent.
- Show a new request over an active trip and confirm its outcome stays unknown.
- Install from the Play test track and verify sign-in, purchase, restore,
  refund/revoke, update flow, crash/ANR, and battery behavior.

Do not retain rider names, addresses, screenshots, or raw Accessibility/OCR
text as release evidence.
