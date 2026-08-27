# Current release audit

Audit date: 2026-08-27

Candidate: `1.0.10+96` (Play bundle device test)

Result: automated release checks pass after the fixes below. Production remains
conditional on the real-device and Play Console gates listed here.

## Fixed in this audit

1. Android release lint found four API-level resource errors. API 27/29 window
   attributes were removed from the Android 8 base splash themes; the API 31
   qualified themes retain them. `:app:lintRelease` now passes.
2. FAQ text no longer promises that an offer shown only while the phone is
   locked will be read.
3. OCR documentation now describes the actual trigger: an active selected-app
   event that may correspond to a visible Uber offer.
4. Manifest and project wording no longer hard-code a platform list where the
   text should stay generic.
5. Stale reports incorrectly claiming `isAccessibilityTool=true` were removed.
   The shipped service explicitly sets it to `false`.
6. Historical plans, handoffs, research notes, and superseded design documents
   were removed after current behavior and release gates were consolidated.
7. Release builds warned that Flutter-retained Cupertino navigation code had no
   icon font. The standard font asset was added and tree-shakes to 848 bytes;
   the missing-font warning is gone.
8. Uber now keeps readable Accessibility data as the primary path and invokes
   OCR only for incomplete cards. Lower-app events no longer discard a stacked
   Uber capture, and a missing Match/Accept OCR line no longer loses an otherwise
   complete Uber card.
9. OCR payout guards reject distance-as-money reads, hold dropped decimals
   before display/persistence, retain conflict protection briefly after clear,
   and repair the two observed corrupt duplicate signatures during history load.
10. History backup import now accepts omitted zero delivery counts, matching its
    own exported JSON. Exports use minute-stamped filenames so repeated backups
    do not overwrite one another. The reported 27-record device backup decodes
    successfully.
11. History offer rows retain the compact verdict/outcome layout, highlight the
    fare with the theme accent, and show the short currency symbol in the aligned
    three-column footer. A widget test covers the content and metric baseline.
12. Clear all history now atomically removes both offer rows and persisted
    session summaries, preventing a stale Last session card after a wipe.
13. Card-miss diagnostics identify Accessibility versus OCR input without
    logging raw offer text.

## Audit coverage and result

| Area | Result |
|---|---|
| Correctness | OCR/Accessibility routing, stale-result handling, outcome correction, persistence, and purchase failure behavior are covered by tests. |
| Security/privacy | No tracked secrets or private keys found; backups disabled; exported Android components are appropriately constrained; Firestore is owner-scoped/default-deny; OCR pixels/text are memory-only; diagnostics are sanitized. |
| Accessibility policy | `isAccessibilityTool=false`; package-scoped and read-only. Disclosure/consent/privacy text agree with implementation. Play declaration and review remain mandatory. |
| Rendering/UI | Existing narrow-screen, large-text, scrolling, overlay geometry, and navigation tests cover the high-risk screens. No verified overflow defect remains. |
| Performance | Capture is event-driven and rate-limited, not continuous; history is bounded; stale work is cancelled. A long real-shift battery/memory run remains a device gate. |
| Architecture | Domain/scoring remains plain Dart; capture and overlay boundaries are explicit. Large UI files are maintainability debt but no speculative release refactor is justified. |
| Dependencies | Shipped npm dependencies report zero vulnerabilities. The Firebase CLI dev toolchain reports five moderate transitive advisories; npm offers only a forced breaking downgrade, so it was not applied. Android/Flutter dependencies still require routine update review after release. |
| Copy/FAQ | Wizard and general product copy are platform-neutral. FAQ privacy, lock-screen, OCR, billing, troubleshooting, and outcome wording were checked against code. |

## Verification evidence

- `dart fix --dry-run`: nothing to fix
- `flutter analyze --fatal-infos`: passed
- Flutter suite: 540 tests passed
- `npm run test:rules`: 5 passed
- `npm audit --omit=dev`: 0 vulnerabilities
- full `npm audit`: 5 moderate transitive dev-tool advisories under
  `firebase-tools`; none are packaged in the Android app
- `./gradlew :app:lintRelease`: passed
- `./scripts/build.sh aab --bump`: passed analysis, 540 Flutter tests, 5
  Firestore rules tests, version bump, signing, and release AAB build
- Previous `./scripts/build.sh aab`: passed analysis, 527 Flutter tests, 5 Firestore
  rules tests, signing/key checks, and the production bundle build
- secret/config/manifest/backup/logging review: passed

Current Play device-test artifact:

- `dist/FoxyCo-v1.0.10+96-release-20260826-2335.aab`
- SHA-256: `914d61f316a4b21f555d5775ca9ef4b335a12b73d105b21d149f2f23bf22b89d`
- Play verification key present; upload through a Play test track for device use

## Comparison with the previous audits

The 2026-08-20 findings remain closed: service export configuration, paid-owner
build expiry, manual outcome/session refresh, CSV formula escaping, feedback
privacy wording, pricing/tester documentation, and vague UI copy are fixed.
The old audit's `isAccessibilityTool=true` review risk is also closed in code;
the service now uses `false`. This audit additionally caught the Android 8/9
resource lint failure and current-doc drift that Flutter analysis did not find.

## History backup audit

CSV history backup is now versioned, locale-independent, capped at 2,000 rows,
formula-safe for spreadsheets, and lossless through its authoritative per-row
JSON. Import rejects malformed/oversized/unknown-schema files before changing
state and writes merge/replace results atomically. Merge preserves local manual
outcomes and final payouts. It covers offer history only; settings and session
summaries remain local preferences rather than backup data.

## External release gates

- Run the current candidate through `MANUAL_TESTS.md` on supported Android
  versions and real selected-app offers, including cross-app Uber OCR latency,
  stale pill clearing, rapid start/stop, lock/unlock, and a 30–60 minute soak.
- Verify Play-installed sign-in, purchase, acknowledgement, refund/revoke,
  restore, reinstall, and missing-key failure behavior.
- Complete the Accessibility declaration and consent-flow video. Google review
  can never be guaranteed solely by code configuration.
- Reconcile the Play Data safety and account-deletion forms with the published
  privacy policy, including retained trial-abuse state.
- Review Play Vitals for crash/ANR/battery evidence before production rollout.

Non-blocking debt: Gradle reports a future built-in-Kotlin migration and minor
launcher/generated-resource warnings. Address these with the next controlled
toolchain/icon update, not by suppressing lint in this release.
