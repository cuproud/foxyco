# FoxyCo

FoxyCo is an Android offer analyzer for gig drivers. It reads offers from the
supported apps a driver selects, applies their distance or hourly rules, and
shows a read-only GOOD, OK, or BAD overlay. The driver always decides.

Current version: `1.0.10+96`.

## Detection

- Every supported app uses package-scoped Android Accessibility text first.
- When enabled, on-device OCR is a fallback for Uber cards whose protected or
  custom-rendered window exposes incomplete Accessibility text.
- Accessibility still supplies watched-app events and outcome evidence for
  Uber; FoxyCo never taps, accepts, declines, or controls another app.
- Screenshots and raw screen text are processed in memory, never persisted,
  and never uploaded.
- `android:isAccessibilityTool` is explicitly `false`.

## Development

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
npm run test:rules
cd android && ./gradlew :app:lintRelease
```

Build signed Play artifacts through `scripts/build.sh`; release bundles fail
closed when signing or the Play licensing public key is missing.

```bash
./scripts/build.sh aab
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Current audit](docs/AUDIT.md)
- [Manual device tests](docs/MANUAL_TESTS.md)
- [Play release runbook](docs/PLAY_RELEASE.md)
- [Firebase setup](docs/FIREBASE_SETUP.md)
- [Privacy policy](docs/legal/privacy.md)
- [Terms](docs/legal/terms.md)

FoxyCo is independent and is not affiliated with, endorsed by, or sponsored
by any driver platform. Platform names and marks belong to their owners.
