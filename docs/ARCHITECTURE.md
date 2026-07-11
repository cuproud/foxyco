# FoxyCo — Architecture

Clean Architecture, layered, feature-first. The rule that pays off later: **business logic never
depends on Flutter, Android, or any plugin.** The `DecisionEngine` must be a plain Dart function you
can unit-test with `dart test` — no device, no emulator. Everything else plugs into it.

---

## Layer layout

Flutter doesn't force compiler-level module boundaries the way Gradle modules do, so we enforce
them by **directory + dependency discipline** (optionally split into local packages under
`packages/` later if we want the compiler to police it). Layers, innermost → outermost:

```
lib/
├── domain/        → Offer, Verdict, Thresholds, DecisionEngine. PURE DART. no Flutter, no plugins.
├── data/          → Drift DB, SharedPreferences/settings, repositories (implement domain interfaces)
├── parser/        → OfferParser interface + per-platform impls (UberParser, HoppParser…). Pure Dart.
├── services/
│   ├── overlay/       → OverlayController — wraps flutter_overlay_window (pill + bubble)
│   └── accessibility/ → AccessibilityWatcher — wraps flutter_accessibility_service, feeds :parser
├── ui/
│   ├── theme/         → design tokens, colors, typography (one source of truth)
│   ├── home/          → home screen + controller
│   ├── settings/      → settings screen + controller
│   ├── onboarding/    → permission walkthrough
│   └── overlay/       → the pill + bubble widgets (rendered in the overlay isolate)
└── main.dart      → app entry, Riverpod ProviderScope, go_router, wiring only
```

Dependency direction (arrows = "depends on"):

```
main → ui → domain
main → services/overlay → domain
main → services/accessibility → parser → domain
data → domain
ui, services, parser → data (repositories only, via domain interfaces)
domain → nothing
```

If `domain/` ever imports `package:flutter/*` or any plugin, the design is broken. That's the one
hard rule. (A quick `grep -r "package:flutter" lib/domain` in CI keeps us honest.)

---

## Data flow (MVP)

```
AccessibilityWatcher (Uber/Hopp window event via flutter_accessibility_service)
   │  receives screen nodes (text + bounds)
   ▼
UberParser.parse(nodes) : Offer?                 [parser]
   │  Offer(payout: 10.55, pickupKm: 0.8, dropoffKm: 4.3, platform: uber)
   ▼
DecisionEngine.evaluate(offer, thresholds) : Verdict   [domain, pure]
   │  totalKm = 5.1, $/km = 2.07 → GOOD
   ▼
OverlayController.show(offer, verdict)           [services/overlay]
   │  draws pill + updates bubble color (flutter_overlay_window)
   ▼
OfferRepository.log(offer, verdict, DateTime.now())   [data, Drift] → home tally
```

> **Isolate note (Flutter-specific):** `flutter_overlay_window` renders the pill/bubble in a
> **separate overlay entrypoint** (`@pragma('vm:entry-point')`), which runs in its own isolate — it
> does **not** share memory with the main UI isolate. Cross-isolate messages
> (`shareData` / `overlayListener`) carry the verdict payload across. Keep that payload a tiny
> plain map (`{verdict, totalKm, payout}`), not a live object graph. This is the single biggest
> structural difference from a native Kotlin build — plan the boundary, don't fight it.

---

## Core models (`domain/`)

```dart
enum Platform { uber, hopp }

enum Verdict { good, ok, bad }

class Offer {
  final double payout;      // dollars
  final double pickupKm;
  final double dropoffKm;
  final Platform platform;
  final bool payIsNet;      // Hopp = true (net), Uber = false (gross)
  final String? rawText;    // for debugging the parser

  const Offer({
    required this.payout,
    required this.pickupKm,
    required this.dropoffKm,
    required this.platform,
    this.payIsNet = false,
    this.rawText,
  });

  double get totalKm => pickupKm + dropoffKm;
  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;
}

class Thresholds {
  final double goodAtOrAbove; // $/km
  final double badBelow;      // $/km
  const Thresholds({required this.goodAtOrAbove, required this.badBelow});
}

class DecisionEngine {
  const DecisionEngine();

  Verdict evaluate(Offer offer, Thresholds t) {
    final ppk = offer.pricePerKm;
    if (ppk >= t.goodAtOrAbove) return Verdict.good;
    if (ppk < t.badBelow) return Verdict.bad;
    return Verdict.ok;
  }
}
```

That's the whole brain for MVP. Everything else is plumbing and pixels.

> Extension point: later, swap the naive `pricePerKm` verdict for a `ProfitEngine` that subtracts
> fuel/wear/tax and returns net $/hr. `DecisionEngine.evaluate` keeps the same signature — only the
> inputs get richer. No caller changes. `payIsNet` already lets us treat Hopp (net) vs Uber (gross)
> correctly when that lands.

---

## State management & navigation

| Concern | Choice | Why |
|---|---|---|
| State management | **Riverpod** (`flutter_riverpod`) | Compile-safe DI + reactive state, testable without widgets. Replaces Hilt+ViewModel from the native plan. |
| Navigation | **go_router** | Declarative routes, deep-link ready, simple for our ~4 screens. |
| Async | Dart `Future` / `Stream` / `async*` | Native to the language; no extra lib. Streams replace Kotlin Flow. |
| Immutability/models | plain classes now; **freezed** if boilerplate grows | Don't add codegen until it hurts. |

Riverpod providers are the seams: `decisionEngineProvider`, `thresholdsProvider` (from settings),
`offerRepositoryProvider`, `overlayControllerProvider`. Swap any for a fake in tests.

---

## Persistence (`data/`)

- **SharedPreferences** (via a `SettingsRepository`) — settings: thresholds, unit (km/mi), pill
  size, pill/bubble position, overlay timeout, active platforms. Simple key/values.
- **Drift** (SQLite) — `OfferLog(id, platform, payout, totalKm, pricePerKm, verdict, timestamp)`.
  Powers the home tally now; becomes the analytics/earnings backbone later. One table, add columns
  as needed. (Drift = typed, reactive queries, Flutter's closest equivalent to Room.)

---

## Tech stack (locked)

| Concern | Choice |
|---|---|
| Framework | Flutter (stable channel) |
| Language | Dart |
| UI | Flutter widgets + Material 3 (`useMaterial3: true`) |
| Arch | Clean Architecture + feature-first layers |
| State / DI | Riverpod |
| Navigation | go_router |
| DB | Drift (SQLite) |
| Settings | SharedPreferences |
| Async | Future / Stream |
| Overlay (native) | `flutter_overlay_window` |
| Accessibility read (native) | `flutter_accessibility_service` |
| Permissions | `permission_handler` |
| Min SDK | 26 (Android 8 — needed for `TYPE_APPLICATION_OVERLAY`, which the overlay plugin uses) |
| Target SDK | 35 |

Deferred deps (don't add until their milestone): `google_maps_flutter`, `google_mlkit_text_recognition`
(OCR), `camera`, `fl_chart` (analytics), Firebase. YAGNI — every unused dep is app size + a
permission to justify on the Play listing.

> **iOS:** out of scope. Even though Flutter *can* target iOS, Apple blocks system overlays and
> accessibility automation of other apps — the two things FoxyCo is built on. Android-only, like
> Maxymo. The Flutter codebase keeps a *theoretical* future door open (screens would port), but the
> core features never will on iOS. Don't spend a minute on it.

---

## Design tokens (full visual language in UI_DESIGN.md)

The **semantic** verdict tokens are fixed now so overlay + screens share one source of truth,
living in `ui/theme/`:

```dart
// ui/theme/tokens.dart
class VerdictColors {
  static const good = Color(0xFF2ED573); // green — "the good one"
  static const ok   = Color(0xFFFFB020); // amber
  static const bad  = Color(0xFFFF4757); // red
}
```

- **Dark-first** — drivers work at night; default to a true-dark/OLED theme.
- **Glanceability** — verdict readable in <0.5 s at arm's length in sunlight. Color + word + icon,
  never color alone (colorblind-safe).
- **Motion** — subtle only: fade in/out, number count-up, elevation. Never block the verdict behind
  an animation. Performance > flourish.
- **Large touch targets** — 48 dp min; the driver is moving.

Full screen designs, component specs, spacing scale, and typography are in
[`UI_DESIGN.md`](UI_DESIGN.md). Keep every token in `ui/theme/` so the M5 visual lock is a token
swap, not a rewrite.

---

## Testing strategy

- `domain/` — `dart test`, 100% of DecisionEngine branches. Fast, no Flutter binding.
- `parser/` — feed captured node fixtures (text + bounds), assert `Offer`. Add a fixture every time
  a real offer format changes.
- `ui/` — `flutter_test` widget tests for home/settings; golden tests for the pill (its whole job is
  to look right at a glance).
- `services/overlay` + `services/accessibility` — manual + integration smoke tests on a real device
  (plugin behavior can't be unit-tested off-device).
- Rule: any non-trivial logic ships with one runnable check. No framework sprawl.
