# FoxyCo 🦊 — the gig driver's offer analyzer

**FoxyCo** watches every incoming delivery/ride offer and, in one glance, tells the driver
whether it's worth taking. Your clever co-driver: spots the good ones, ignores the junk.

- **Platform:** Android (built with **Flutter** — Dart UI, native Android plugins for the system parts)
- **Model:** 100% free, offline-first, no login, no cloud, no analytics
- **Package (placeholder):** `com.foxyco.app` — changeable before first release
- **Status:** planning / pre-code

> **Why "FoxyCo"?** *Foxy* = clever, quick, good at spotting value. *Co* = your co-driver /
> companion riding shotgun on every trip. Friendly + trustworthy — the two things a money tool
> for drivers needs.

---

## What it does (MVP v0)

```
Offer appears on Uber / Hopp
        ↓
Accessibility plugin reads it (payout $, pickup km, dropoff km)
        ↓
total km = pickup + dropoff
$/km = payout / total km
        ↓
verdict = GOOD / OK / BAD   (driver-set thresholds)
        ↓
One-line PILL shows in the dead zone + draggable BUBBLE always on top
```

That's the whole MVP. One job, done fast (<300 ms detect→verdict).

**Not in MVP** (architecture leaves room, not built): fuel/wear/depreciation math, net profit,
taxes, mileage tracking, expenses, maps, analytics, AI, more platforms, backups. See
[`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Why Flutter (and what stays native)

FoxyCo's **screens** — home, settings, onboarding, the expanded verdict card — are pure Flutter:
one Dart codebase, fast to build, easy to restyle in the M5 visual pass.

Two things can't be pure Flutter because they're deep Android system features. FoxyCo uses
maintained Flutter plugins that wrap the native Android APIs:

| Native capability | Handled by |
|---|---|
| Draw the pill/bubble on top of other apps | [`flutter_overlay_window`](https://pub.dev/packages/flutter_overlay_window) |
| Read the offer off the Uber/Hopp screen | [`flutter_accessibility_service`](https://pub.dev/packages/flutter_accessibility_service) |

The **brain** (parse → score → verdict) is plain Dart with zero Android dependencies, so it's
unit-testable with no emulator. That's the one rule that pays off later. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## The overlay (the core UX)

Two pieces, both live over the driver's active app (Uber / Hopp):

1. **Pill** — single line, floats in the top dead-zone but dropped below the very top edge so
   it never covers the platform's own X / decline / fare. Content: `⬤ GOOD · 8.4 km · $12`.
   Resizable (S/M/L), draggable. Tap = expand breakdown.
2. **Bubble** — always-on draggable dot (Maxymo/Messenger style). Verdict color at a glance.
   Tap = jump into FoxyCo to tweak filters/settings. Long-press = pause/resume.

Full spec + the research on how Uber/Hopp lay out their request screens:
[`docs/OVERLAY.md`](docs/OVERLAY.md).

---

## Docs

| Doc | What's in it |
|-----|--------------|
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones M0→M6, the detailed build steps. **Start here.** |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Flutter clean architecture, layers, packages, data model, design tokens |
| [`docs/UI_DESIGN.md`](docs/UI_DESIGN.md) | Screen-by-screen UI design: mockups, components, tokens, motion, a11y |
| [`docs/OVERLAY.md`](docs/OVERLAY.md) | Screen-geometry research + pill/bubble spec + how the plugins read/draw |
| [`docs/REFERENCE_ANALYSIS.md`](docs/REFERENCE_ANALYSIS.md) | Uber + Hopp screenshot breakdown → design + parser base |
| [`docs/AUDIT.md`](docs/AUDIT.md) | Pre-flight audit: Play policy, ToS risk, battery, privacy, perf, a11y |
| [`docs/TOOLING.md`](docs/TOOLING.md) | Flutter SDK + packages + Android dev env + verification |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Decision log — every choice + why, so nothing gets re-litigated |

---

## Decisions locked so far

- **Name:** FoxyCo (package `com.foxyco.app`, placeholder)
- **Stack:** Flutter (Dart) + native Android plugins for overlay & accessibility
- **Scope:** MVP-first (offer analyzer only), architecture scales to full platform later
- **Overlay:** top pill (dropped from edge) + draggable bubble, single line only
- **Overlay content:** verdict · total km · payout — no fuel/wear math yet
- **Thresholds:** driver-set in settings, seeded with defaults
- **Base platforms:** Uber + Hopp (real screenshots supplied as parser + design base)
- **UI visual language:** direction proposed in `docs/UI_DESIGN.md`, locked at M5

Open / deferred items are tracked in [`docs/DECISIONS.md`](docs/DECISIONS.md).
