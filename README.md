# FoxyCo

FoxyCo is an Android offer analyzer for gig drivers. It calculates distance and
hourly value from selected apps, then shows a read-only **GOOD**, **OK**, or
**BAD** overlay. The driver always decides. Current release: `1.0.14+103`.

## Detection

- Accessibility text is primary. Uber can use rate-limited, on-device OCR when
  its offer text is unavailable through Accessibility.
- OCR is bounded to the visible Uber card, so text from a Lyft, Hopp, or other
  card behind it cannot be combined into the calculation.
- Uber temporarily replaces a covered verdict, then restores it for a fresh
  five seconds when Uber closes.
- Suspicious OCR values such as a dropped decimal are retried and never scored
  or saved.

Screenshots and raw screen text stay in memory and are never uploaded or saved.
FoxyCo never taps, accepts, declines, or controls another app.

## Development

Install dependencies and run the local checks with `flutter pub get`,
`flutter analyze --fatal-infos`, and `flutter test`. Create a signed Play bundle
with the guarded release helper:

```bash
./scripts/build.sh aab
```

The helper also runs Firestore rules tests and fails closed if signing or Play
licensing configuration is missing.

See the canonical [offer detection and verdict logic](docs/OFFER_DETECTION.md),
[architecture](docs/ARCHITECTURE.md), the [release audit](docs/AUDIT.md),
[device tests](docs/MANUAL_TESTS.md), and the [Play release guide](docs/PLAY_RELEASE.md).
Legal pages are under [docs/legal](docs/legal/).

FoxyCo is independent and is not affiliated with, endorsed by, or sponsored by
any driver platform. Platform names and marks belong to their owners.
