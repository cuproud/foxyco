# 2026-07-11 — Overlay bubble/pill: made it actually work on-device

## State: overlay works end-to-end (debug build, Galaxy S24 / Android 16)

Verified live via wireless adb: pill floats → collapses to fox bubble (12s) →
drags left/right → touch free elsewhere → no snackbar.

## Root causes fixed (in order found)

1. **Off-screen pill** — full-cover overlay window is anchored shifted up
   (−272px, native `-statusBarHeightPx()`), so top-aligned content floated above
   the screen (over the battery). Fix: went to a COMPACT window.
2. **Whole-screen touch trap** — a full-cover window with a focusable flag
   intercepts EVERY touch → locked the phone. Fix: compact window only captures
   touch over itself.
3. **Bubble centered / undraggable** — one fixed 300dp-wide window centered the
   bubble mid-screen. Fix: window starts bubble-sized (64dp), the overlay isolate
   `resizeOverlay`s it up to pill size (300×84) on an offer, back down on clear.
4. **Pill race** — `shareData` fired before the overlay isolate's listener
   attached → payload dropped. Fix: `showOffer` settles 350ms on first show.
5. **Snackbar over nav bar** — removed entirely (user request).

## Key facts learned (don't re-derive)

- Plugin `showOverlay` initial size = raw PHYSICAL px (no dp→px). `resizeOverlay`
  DOES convert (takes dp). See `_dpToPx` in overlay_service.dart.
- `moveOverlay`/`getOverlayPosition` run on the MAIN plugin channel → useless
  when FoxyCo is backgrounded. `resizeOverlay`/`shareData`/`updateFlag` run on
  the overlay-engine channel → callable from the overlay isolate.
- Native `onTouch` drags the window with NO vertical clamp; on release snaps X to
  an edge, leaves Y. That's why the bubble stuck under the nav bar.
- Real device pkg = `com.foxyco.app` (applicationId), namespace `com.foxyco.foxyco`.
- Phone reaches this WSL only over wireless adb (`adb connect <ip>:<port>`).

## Vendored plugin fork — UNVERIFIED, do first tomorrow

`third_party/flutter_overlay_window` (pubspec `dependency_overrides`) patches
native `onTouch`: releasing a drag in the bottom nav-bar zone
(`event.getRawY() >= szWindow.y - dpToPx(72)`) calls `stopSelf()` → drop-to-
dismiss. Built fine but the on-device drag test was interrupted → **verify
MANUAL_TESTS rows 2.10 and 2.14 first.**

## Loose ends

- `debugPrint('FoxyCo[overlay] ...')` markers still in overlay_entry.dart /
  main.dart — handy for now, strip before release.
- `_kOverlayDebug` (magenta tint) is OFF but left in place as a probe.
- `_simulate(context, ...)` keeps an unused `context` param (harmless).
- Overlay is still debug-build only; not yet tested as a release APK.
