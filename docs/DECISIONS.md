# FoxyCo — Decision Log

Append-only. Every locked choice + why, so we don't re-argue it. Open items at bottom.

---

## Locked

| # | Decision | Why | Date |
|---|----------|-----|------|
| 1 | **Name: FoxyCo** 🦊 | *Foxy* = clever/quick at spotting value; *Co* = co-driver companion + "company" credibility. Friendly + trustworthy, the two things a driver money-tool needs. (Started as "Fox"; renamed 2026-07-10.) | 2026-07-10 |
| 2 | **MVP-first scope** | `first.txt` (offer analyzer) and `project.txt` (mega-platform) conflict. Build the one killer feature first on an architecture that scales to the rest. | 2026-07-09 |
| 3 | **Overlay = top pill (dropped from edge) + draggable bubble** | Uber/Hopp take the bottom ~40% + a top-right X/Decline. Only safe zone is the top map area, dropped down to clear the X. Bubble = persistent quick-access handle. | 2026-07-09 |
| 4 | **Single-line pill, content = verdict · total km · $payout** | User: no fuel/wear/net math yet. Total km = pickup + dropoff. $/km drives the verdict. | 2026-07-09 |
| 5 | **Thresholds driver-set, seeded with defaults** | Core knob, expose it from v0. Defaults: GOOD ≥ $1.50/km, OK $1.00–1.49, BAD < $1.00. | 2026-07-10 |
| 6 | **Base platforms: Uber + Hopp** | User supplied real Uber + Hopp offer screenshots as the design + parser base. Both reliably show pay + pickup dist + trip dist on one card. DoorDash deferred to M6. | 2026-07-10 |
| 7 | **Read-and-advise only; auto-accept deferred** | Auto-clicking platform buttons violates ToS and risks driver deactivation + Play removal. Advise-only is safe. | 2026-07-10 |
| 11 | **Strictly manual — hard rule, not a deferral (hardens #7)** | User directive: FoxyCo NEVER performs any action inside another app — no auto-accept/decline, no taps, no gestures, ever. Accessibility is read-only; the only actions FoxyCo takes are on its own overlay/app. This is a permanent product boundary, stated verbatim in onboarding's disclosure. | 2026-07-16 |
| 8 | **Stack: Flutter (Dart)** — Riverpod, go_router, Drift, SharedPreferences; native Android via `flutter_overlay_window` + `flutter_accessibility_service`; min SDK 26, target 35 | **Supersedes the previous Kotlin decision.** User chose Flutter. One codebase, fast UI iteration, and the two system features are covered by maintained plugins that wrap the same Android APIs. Trade-off accepted: overlay runs in a second isolate (extra memory, cross-isolate messaging) and we depend on community plugins — both mitigated in AUDIT #4/#9. SDK 26 still needed for `TYPE_APPLICATION_OVERLAY`. | 2026-07-10 |
| 9 | **iOS out of scope despite Flutter being cross-platform** | Apple blocks system overlays + accessibility automation of other apps — FoxyCo's two core features. Android-only like Maxymo. Flutter keeps screens theoretically portable, but the core never will be. | 2026-07-10 |
| 10 | **Full UI design proposed now (UI_DESIGN.md), visual language locked at M5** | User asked for UI designs up front. Screens, components, tokens, and a recommended visual direction are documented; the final look is confirmed after the skeleton runs on a device. | 2026-07-10 |
| 12 | **Outcome inference is passive + optional (respects #11)** | Taken/missed is GUESSED from the screen that replaces the offer card (browse/map = passed, in-trip nav = taken) — read-only, no new permissions, no taps. Presented as "Likely taken/passed", never certainty. Driver can turn it off (Settings → Outcome tracking, default ON); off = every offer logs unknown. | 2026-07-20 |
| 13 | **Car reminders are in-app only (no notification permission)** | Inspection/insurance/maintenance dates surface as a Home banner inside the lead window, not as system notifications — zero new permissions for a Play-sensitive a11y app. Real push (flutter_local_notifications + exact alarms) deferred until a driver asks. | 2026-07-20 |

---

## Superseded

| Old decision | Replaced by | When |
|---|---|---|
| **Stack: Kotlin/Compose/M3/Hilt/Room/DataStore** | #8 (Flutter) | 2026-07-10 |
| **Name: Fox** | #1 (FoxyCo) | 2026-07-10 |

---

## Open — need your call (not blocking M0/M1)

- **Package name** — `com.foxyco.app` placeholder. Lock before first signed build (can't change post-publish).
- **Distribution** — Play Store (with accessibility disclosure) vs sideload/direct APK. Decide by M4. See AUDIT #1.
- **Visual direction** — Kinetic HUD / Aurora Glass / Neo-Tactile (see UI_DESIGN.md). Lock at M5.
- **Units** — km or mi default? (km assumed; settings toggle either way.)
- **Third platform** — DoorDash vs Lyft for M6.

---

## Rejected / parked

- Auto-accept in MVP — parked (ToS/deactivation risk).
- Full mega-platform up front — parked (build MVP first).
- Native Kotlin — parked in favor of Flutter (#8). Note: if the community plugins ever prove
  unworkable, native Kotlin is the documented fallback (all the M0-plan groundwork is in git history).
- iOS — out of scope (Apple blocks overlays + accessibility automation).
- Names considered: Fox, FoxyGo, FoxPilot, SmartFox, GigPilot, Hawk, Falcon, Plum, Cherry.
