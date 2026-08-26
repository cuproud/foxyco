# Architecture

Updated 2026-08-26 for `1.0.10+90`.

## Boundaries

```text
Android Accessibility event
  ├─ complete selected-app nodes → matching parser
  └─ incomplete Uber nodes + OCR approved
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

Accessibility is the primary source for every platform, including Uber. Uber
OCR is an opt-in fallback only when a card's protected or custom-rendered window
exposes incomplete nodes. Accessibility still supplies event origin, screenshot
access, card lifecycle, and outcome evidence. An Uber request drawn over another
selected app keeps its Uber origin, and lower Lyft/Hopp events do not invalidate
the visibly stacked Uber screenshot. Uber lifecycle evidence still rejects a
stale result after its card leaves.

OCR payout changes are confirmed before replacing a live or just-cleared Uber
offer. A first implausible dropped-decimal value is never scored or persisted;
complete Uber economics remain sufficient when OCR misses the dark Match/Accept
button.

Other supported offers use Accessibility text. Events are statically limited
to known package names in `android/app/src/main/res/xml/accessibilityservice.xml`
and filtered again by the driver's selected apps before parsing. Adding a
platform requires metadata, explicit package scope, parser fixtures, and device
validation; user-facing copy therefore refers generically to supported apps.

## Persistence

SharedPreferences stores settings, garage/reminders, offer history, and session
summaries as version-tolerant JSON. An offer record preserves:

- captured payout, bonus, pickup/drop-off distance, duration, workload, app,
  category, queue state, verdict, timestamp, and scoring snapshot;
- detected outcome separately from a manual outcome correction; and
- original payout separately from a manually entered final payout.

Manual corrections win over later inference. History is capped and retention
can be configured. Android backup and data extraction are disabled.

History hydration collapses the two known OCR correction signatures: a dropped
payout decimal (`$7.54`/`$754`) and pickup distance misread as payout. The
corrected row drives tallies and analytics.

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
- System text scale plus the in-app text multiplier is capped at 2×; focused
  widget tests cover narrow screens, large text, scrollability, and overlay
  geometry.
- The overlay runs in its own isolate; only small serialized verdict payloads
  cross the boundary.

## Verification rule

Every release candidate must pass Flutter analysis/tests, Firestore rules
tests, Android release lint, a signed release build, and the real-device matrix
in `MANUAL_TESTS.md`. Parser correctness and overlay behavior cannot be proven
by host tests alone.
