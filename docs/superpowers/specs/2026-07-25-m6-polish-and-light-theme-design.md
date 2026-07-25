# M6 polish + light theme — design

**Date**: 2026-07-25
**Branch**: m6-showroom
**Status**: approved, implementing

Seven changes from a device session on 2026-07-24/25. Ordered by landing
sequence; the theme is last because it touches every file the others edit.

---

## 1. Slide-to-go-live: full-width glass cue

**Problem.** `slide_to_live.dart:192` parks `_MarchingChevrons` at
`right: _thumb` with a 60 px band (`_count 3 × _step 20`). On a ~340 px track
the cue occupies the last ~100 px and reads as a small detail rather than an
invitation to sweep the whole card.

**Design.** Two layers under the label, both fading out on `1 - _drag * 2` as
the orange fill rises (same fade the label already uses):

- **Shimmer sweep** — a `LinearGradient` band (cream at ~8% alpha, transparent
  at both stops) translated across the full track width on a ~1.8 s loop.
- **Chevron train** — the existing marching chevrons, widened to span the whole
  track instead of a 60 px band.

Reduced motion (`MediaQuery.disableAnimations`) renders both static, matching
`_MarchingChevrons`' current contract. The stop bar keeps its mirrored
(leftward) treatment.

Scope: `slide_to_live.dart` only.

---

## 2. Card text overflow audit

**Problem.** `home_screen.dart:948` — the session header row is
`[icon][3h 24m][on watch][Spacer][when]` with `when` an unbounded `Text`. Once
the date prefix landed (`Jul 23, 2026 · 7:31 PM – 7:31 PM`) the row overflows
the card. There is also no gap between `on watch` and the date.

**Design.** Fix that row, then sweep the app for the same shape: any `Row`
containing a `Text` that is neither `Expanded` nor `Flexible` and carries no
`overflow`. Verify at 320 dp width and 1.3× text scale, since that combination
is what actually surfaces these.

Files to sweep: `home_screen.dart`, `history_screen.dart`,
`settings_screen.dart`, `offer_detail_sheet.dart`, `shift_recap_sheet.dart`,
`verdict_pill.dart`, `vehicle_editor_screen.dart`, `onboarding_screen.dart`.

---

## 3. Garage art sizing

**Problem.** `vehicle_badge.dart:10` claims the PNGs are autocropped to the
artwork. Measured alpha bounding boxes (threshold α > 16) say otherwise:

| asset | canvas ar | content ar | wasted canvas |
|---|---|---|---|
| `ev` | 0.90 | 2.04 | 67% |
| `off_road` | 0.87 | 1.21 | 50% |
| `bike` | 0.84 | 1.12 | 50% |
| `premium` | 1.16 | 1.70 | 40% |
| `e_bike` | 0.71 | 0.97 | 37% |
| `ev_van` | 1.55 | 1.59 | 15% |
| `e_scooter` | 0.66 | 0.66 | 12% |
| sedan/suv/van/pickup/hatchback/suv_comfort | 2.3–2.5 | — | 11–13% |

The editor preview is `AspectRatio(1.7)` + `BoxFit.contain`
(`vehicle_editor_screen.dart:132`). `contain` fits the *canvas*, so a padded
tall canvas binds on height: the car renders small, floats off-centre, and the
whole frame reads as vertically stretched.

**Design.** Two parts:

1. **Trim the canvases** to their content bbox plus a small uniform pad, for
   `ev`, `off_road`, `bike`, `premium`, `e_bike`, `ev_van`. Pure asset change.
2. **Normalise visual mass.** `e_scooter` (and `e_bike` after trimming) are
   honestly tall — a standing scooter is ~0.66:1. Under `contain` in a 1.7 box
   they render at full card height while a sedan renders at ~68% of it. Add a
   per-type width fraction in `VehicleBadge` so every body reads at comparable
   size regardless of its natural ratio.

---

## 4. About screen

**Design.** `lib/ui/settings/about_screen.dart`, pushed from Settings the same
way `logs_screen.dart` already is. Copy lives in
`lib/ui/settings/about_content.dart` as a `const` list of records so adding an
FAQ entry is one line and touches no widget code.

Sections: what FoxyCo does · how it reads offers (the accessibility
disclosure) · privacy (nothing leaves the device) · FAQ · troubleshooting ·
version and build.

---

## 5. Bubble never closes outside the gig apps

**Problem.** `android/app/src/main/res/xml/accessibilityservice.xml:19` scopes
the service to the three gig packages. That scoping is deliberate — AUDIT #4
(battery) and AUDIT #1 (don't over-request, for Play review). The consequence:
once any other app is foregrounded, Android delivers FoxyCo **zero** events, so
`OfferWatcher._onRead` never runs and the clear timer at `offer_watcher.dart:198`
never arms. The pill stays up indefinitely.

`overlay_controller.dart:172` refers to "the 45 s safety timer". No such timer
exists in Dart or in either `third_party/` fork.

**Rejected — unscoping the service.** Would let us detect the foreground app
directly, but reverses two documented audit mitigations for what is ultimately a
pill timer.

**Rejected — flat max-visible lifetime.** A blanket 7 s would blink the pill away
inside Uber while the driver is still reading a live card.

**Design — idle watchdog.** Reset a timer on *every* read from a watched
package; clear the pill when it expires.

- Inside a gig app the event stream machine-guns (it is debounced at
  `accessibility_watcher.dart:31` precisely because of this), so the timer keeps
  resetting and the pill holds for as long as the card is up. Existing
  fast-decline clearing is untouched.
- Leaving the gig app produces silence, which is the only signal available under
  the scoped service — the timer runs out and the pill clears.

Default 7 s, exposed as an `@visibleForTesting static Duration` alongside
`clearGrace` and `minVisible`, so it is one number to retune on device if a card
ever sits 7 s without emitting an event. Also delete the stale 45 s comment.

---

## 6. Last session card

**Problems.**

1. `SessionLog` persists correctly (`foxyco.session_log.v1`, 100 entries) — it
   is not wiped daily. What the device showed was a genuine 0-minute session
   (Jul 23, 7:31 PM → 7:31 PM) burying the real 3h 24m one, because
   `dashboard_controller.dart:93` records every start→stop including a mis-slide.
2. The date only renders when the session is not from today
   (`home_screen.dart:929`), so a same-day session shows bare times.
3. The card's layout is cramped next to the shift-recap sheet.

**Design.**

- **Don't record trivial sessions.** Skip sessions under 60 s that saw zero
  offers. A mis-slide can no longer bury a real shift.
- **Always show the date.** Absolute date for any session, laid out so it cannot
  overflow (see §2).
- **Recap-style layout.** Rebuild the card on the shift-recap sheet's structure:
  title row with duration right-aligned, big count + `offers scored`, the three
  verdict pills, then the three stat tiles (`BEST $/KM`, `GOOD AVG`, `BUSIEST`).
- **`SessionSummary` gains** `bestPerKm`, `goodAvgPerKm`, `busiestHour`,
  computed from `OfferStats.from(offers)` at record time. Null-safe `fromJson`
  so existing saved blobs still load and simply render `—` in the tiles.
- **Share the widgets.** Lift `_pill` and `_cell` out of `shift_recap_sheet.dart`
  into a shared file so the card and the sheet cannot drift apart.

---

## 7. Light theme

**Problem.** The dark theme is unreadable in daylight. `FoxColors` is
`static const`, referenced 207 times across 19 files, much of it inside
`const TextStyle(...)` / `const BoxDecoration(...)`.

**Design.** Theme-aware palette, dark and light, with a `ThemeMode` control in
Settings persisted to `FoxSettings` (defaulting to the current dark).

Consequences to handle rather than discover:

- Every `const` widget literal embedding a `FoxColors` value loses its `const`.
  Mechanical and compiler-enumerated, but it is the bulk of the diff.
- The hero car render is a black car on black. In light mode it needs a dark
  plate behind it; the same applies to the splash screen.
- The overlay pill runs in a separate isolate and floats over other apps' UI.
  It stays dark in both modes.

Landed last, so it does not collide with §1–§6.

---

## Verification

`flutter analyze` clean and `flutter test` green after each of the seven.
Device rows added to `docs/MANUAL_TESTS.md` for: the go-live sweep, each
repaired vehicle in the editor, the About screen, the pill clearing after
leaving a gig app, the last-session card surviving a day boundary, and both
themes in daylight.
