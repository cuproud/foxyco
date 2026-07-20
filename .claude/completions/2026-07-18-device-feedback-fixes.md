# 2026-07-18 — Device-feedback fixes (post-M6 install review)

User installed the M6 build on device and reported 6 issues. All but two are
fixed in code; two need a user decision (documented below).

## Fixed

1. **Slide-to-stop dead** (`lib/ui/home/slide_to_live.dart`)
   Root cause: in the live bar the stop thumb was positioned at `left: 6 + x`
   with `_drag` starting at 0 → thumb RESTED AT THE LEFT END. A right→left
   stop drag therefore had no travel (finger already at the left edge), so
   commit fraction 0.85 was unreachable → stop never fired. It also sat on top
   of the "Live" label (the screenshot's clipped "ve" text).
   Fix: thumb now rests at the RIGHT end (`left: 6 + (travelPx - x)`) and
   travels left. Widget test 'drag back stops' passes (it dragged −320 px,
   which masked the bug — real fingers can't leave the screen).

2. **Blank white pill top-right when off** (`lib/ui/home/home_screen.dart`,
   `_LivePill`) — Off state used `FoxColors.cream` background with cream-family
   text → cream-on-cream invisible label. Now `bgSurface2` + hairline border;
   reads "Off".

3. **No save affordance for name** (`lib/ui/settings/settings_screen.dart`,
   `_DriverNameCard`) — save existed but was a lone check ICON, user read it
   as no-save. Now: labeled orange "Save" FilledButton while dirty, keyboard
   Done saves too, snackbar "Name saved" confirms, focus unfocuses.
   NB: FilledButton needed `minimumSize: Size(0, 44)` — theme default is
   `Size.fromHeight(52)` (infinite width) which explodes inside a Row.

4. **$/km font** (`lib/ui/overlay/verdict_pill.dart`) — figure now Fraunces
   w700 (premium serif, matches Home's big numbers); `/km`, `km`, `$/hr` get
   explicit Inter (overlay isolate has no theme → unset family fell back to
   Roboto).

5. **Plasma status ring** (`lib/ui/overlay/verdict_pill.dart`,
   `_PlasmaBorder`/`_PlasmaPainter`) — animated ring around the pill in the
   verdict color: faint static outline + two orbiting comet arcs (sweep
   gradient, 2.4 s loop), soft glow pass. `animate: false` renders it static
   (settings preview uses this — pumpAndSettle would never settle otherwise;
   reduced motion also freezes it).

6. **Uber never parses — diagnostic laid** (`accessibility_watcher.dart`,
   `parse_health.dart`, `offer_watcher.dart`, settings) — watcher no longer
   swallows textless frames; they're counted per platform
   (`PlatformHealth.textlessFrames`) and ≥10 with 0 parses shows
   "Unreadable · OCR needed" in Settings parser health. This distinguishes
   "Uber renders on canvas/Compose (a11y tree empty → OCR fallback needed)"
   from "selectors stale".

## Needs user decision (NOT implemented)

- **OCR fallback for Uber** (user's proposed flow: a11y event → screen
  capture → detect card → OCR → extract → overlay). Requires:
  - `AccessibilityService.takeScreenshot()` (API 30+) via a patched/forked
    accessibility plugin (flutter_accessibility_service 1.2.0 has no
    screenshot API — only the global-action constant), AND
  - an OCR dependency (`google_mlkit_text_recognition`, on-device).
  CLAUDE.md requires explaining new dependencies before adding. Also verify
  on-device first whether Uber frames are truly textless (M6F.9 manual test)
  — if text exists but patterns changed, a parser re-tune is far cheaper.
- **Hero card redesign** — 3 staged options in
  `references/foxyco_hero_options.html` (open in a browser):
  A Showroom Spotlight (light cone + float + reflection),
  B HUD Platform (holo-ring + live stat chips + scanline),
  C Garage Portrait (pre-rendered PNG pack + ghosted model name).
  Vehicle model/color selection already exists (Garage); onboarding picker to
  follow the chosen direction.

## Validation

`flutter analyze` clean; `flutter test` 160/160 pass.
Manual rows added: docs/MANUAL_TESTS.md §M6.1 (M6F.1–M6F.13).

## Round 2 (same day, after reinstall)

7. **Demo button behind bottom nav** (`home_screen.dart`) — fixed bottom pad
   100 didn't include the gesture-bar inset (`extendBody: true` shell). Now
   `100 + MediaQuery.padding.bottom`.
8. **Offline demo leaves bubble** (`overlay_controller.dart`) — demo timer now
   checks watch status: offline → `hide()` whole window; live → `clearPill()`.
9. **Stale pill state across window sessions** (`overlay_service.dart`) —
   `closeOverlay` kills the WINDOW but the overlay ISOLATE + widget state
   survive. Offline demo → go live re-created a bubble-sized (72 dp) window
   with the old `_payload` still set → clipped pill text where the bubble
   should be. Fix: `startWatching` sends `clearPill` whenever it creates the
   window (skipped if already active, so live pills aren't wiped);
   `hide()` also clears the pill before closing as second defense.

