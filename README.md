# FoxyCo 🦊 — the gig driver's offer analyzer

**FoxyCo** reads supported delivery and ride offers, compares them with the
driver's rules, and shows a GOOD, OK or BAD verdict. The driver always decides.

- **Platform:** Android (built with **Flutter** — Dart UI, native Android plugins for the system parts)
- **Model:** 7-day Google-account trial, then one-time lifetime unlock; no subscription or analytics
- **Play package:** `com.foxyco.app` — locked; do not change
- **Status:** build 55 source audited; signed device, billing and Play-policy gates remain

> **Why "FoxyCo"?** *Foxy* = clever, quick, good at spotting value. *Co* = your co-driver /
> companion riding shotgun on every trip. Friendly + trustworthy — the two things a money tool
> for drivers needs.

---

## What it does

```
Offer appears on Uber / Lyft / Hopp
        ↓
Accessibility reads it first; optional on-device OCR handles unreadable cards
        ↓
total km = pickup + dropoff
rate = payout / total distance (km or mi), or payout / hour
        ↓
verdict = GOOD / OK / BAD   (driver-set thresholds)
        ↓
One-line PILL shows in the dead zone + draggable BUBBLE always on top
```

That's the core. One job, done fast (<300 ms detect→verdict).

**Beyond that (built):** history with filters + hourly / per-app charts, offer detail
sheet with verdict math, shift recap, optional taken/passed inference (read-only), car
reminders (inspection/insurance/maintenance dates), CSV export, garage + driver profile,
$/km or $/hr thresholds with presets.

**Not built** (architecture leaves room): fuel/wear/depreciation math, net profit,
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
| Read the offer off Uber/Lyft/Hopp first | [`flutter_accessibility_service`](https://pub.dev/packages/flutter_accessibility_service) |
| Optional in-memory OCR fallback | Accessibility screenshot + bundled ML Kit Text Recognition |

The **brain** (parse → score → verdict) is plain Dart with zero Android dependencies, so it's
unit-testable with no emulator. That's the one rule that pays off later. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## The overlay (the core UX)

Two pieces, both live over the driver's active app (Uber / Lyft / Hopp):

1. **Pill** — single line, floats in the top dead-zone but dropped below the very top edge so
   it never covers the platform's own X / decline / fare. Content: `$1.03/km · 19.4 km · $45/hr`.
   Resizable (S/M/L), draggable. Read-only — taps on it are absorbed, never passed to the gig app.
2. **Bubble** — always-on draggable dot (Maxymo/Messenger style). Verdict color at a glance.
   Tap = jump into FoxyCo to tweak filters/settings. Long-press = pause/resume.

Both hide while the screen is off or the phone is locked, and return on unlock — the watcher
keeps running underneath.

Full spec + the research on how Uber/Hopp lay out their request screens:
[`docs/OVERLAY.md`](docs/OVERLAY.md).

---

## Docs

| Doc | What's in it |
|-----|--------------|
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestones M0→M10, the detailed build steps. **Start here.** |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Flutter clean architecture, layers, packages, data model, design tokens |
| [`docs/UI_DESIGN.md`](docs/UI_DESIGN.md) | Screen-by-screen UI design: mockups, components, tokens, motion, a11y |
| [`docs/OVERLAY.md`](docs/OVERLAY.md) | Screen-geometry research + pill/bubble spec + how the plugins read/draw |
| [`docs/REFERENCE_ANALYSIS.md`](docs/REFERENCE_ANALYSIS.md) | Uber + Hopp screenshot breakdown → design + parser base |
| [`docs/AUDIT.md`](docs/AUDIT.md) | Pre-flight audit: Play policy, ToS risk, battery, privacy, perf, a11y |
| [`docs/FULL_APP_AUDIT_2026-08-20.md`](docs/FULL_APP_AUDIT_2026-08-20.md) | Current build-55 audit, fixes and remaining release gates |
| [`docs/PLAY_RELEASE.md`](docs/PLAY_RELEASE.md) | Store listing, policy declarations, signing, and the release checklist |
| [`docs/MONETIZATION_v1.0.md`](docs/MONETIZATION_v1.0.md) | Trial + one-time unlock: entitlement rules, Play Billing, anti-tamper |
| [`docs/PRICING_STRATEGY_2026-08-20.md`](docs/PRICING_STRATEGY_2026-08-20.md) | Current CA/US pricing, trial and lifetime-model analysis |
| [`docs/MANUAL_TESTS.md`](docs/MANUAL_TESTS.md) | Device test log — exact-number checks per build |
| [`docs/TOOLING.md`](docs/TOOLING.md) | Flutter SDK + packages + Android dev env + verification |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Decision log — every choice + why, so nothing gets re-litigated |

---

## Decisions locked so far

- **Name:** FoxyCo (published package `com.foxyco.app`)
- **Stack:** Flutter (Dart) + native Android plugins for overlay & accessibility
- **Scope:** offer analyzer first; architecture scales to full platform later
- **Overlay:** top pill (dropped from edge) + draggable bubble, single line only
- **Overlay content:** rate · total distance · $/hr — no fuel/wear math yet
- **Thresholds:** driver-set in settings, seeded with defaults
- **Base platforms:** Uber + Lyft + Hopp (real screenshots supplied as parser + design base)
- **UI visual language:** direction proposed in `docs/UI_DESIGN.md`, locked at M5

Open / deferred items are tracked in [`docs/DECISIONS.md`](docs/DECISIONS.md).
