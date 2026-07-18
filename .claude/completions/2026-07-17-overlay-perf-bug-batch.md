# 2026-07-17 — Overlay performance + pill-math bug batch

Bug reports (screenshots in `references/bugs/`, taken 2026-07-17 on device):
1. Bubble/pill unresponsive — no drag, no close, tap didn't open app; user
   force-closed the bubble from the app.
2. Pill math wrong (distances ~doubled).
3. Dark gradient box behind bubble AND pill.
4. Parsing very slow.
5. On decline/close the pill stuck around for a long time.

## Root causes + fixes

### 1+4+5 — ONE root cause: all a11y processing ran on the main thread
`AccessibilityListener.onAccessibilityEvent` did, per event (~3/s during a live
card): depth-60 recursive walk of the event source, the active root, AND every
same-package window (each node = binder IPC), then Gson-serialized the whole
node dump into SharedPreferences. All on the app process's main thread — the
same thread the overlay window's touch handling and the clearPill message pump
run on. Under an offer storm the main thread was saturated: touches dropped
(bug 1), reads emitted seconds late (bug 4), and the clear message processed
late so the pill lingered (bug 5).

**Fix** (`third_party/.../AccessibilityListener.java`): copy the event
(`AccessibilityEvent.obtain`, recycled in `finally`), post processing to a
single background `HandlerThread` (`foxyco-a11y`). New events evict queued
not-yet-started work (`removeCallbacksAndMessages`) so we always parse the
freshest frame — no stale backlog.

Also bounded `nodeMap`: `LruCache` ctor arg is ENTRY COUNT, not bytes — the
old `4*1024*1024` was effectively unbounded (memory pressure → jank/OOM over
long sessions). Now 512.

### 2 — Pill math: duplicate node walk doubled every leg
The "FoxyCo TEMP diagnostic v2" block in `collectSamePackageWindows` walked
each window into a SEPARATE `probeSeen` set and merged all nodes into the
output. Nodes already captured from the event source were appended AGAIN, so
`foldLegs` saw each leg twice → doubled km/min. Replaced with the original
loop using the SHARED `traversedNodes` set (the `if (true) return;` temp hack
removed too).

### 3 — Dark gradient: opaque FlutterTextureView
`third_party/flutter_overlay_window/.../OverlayService.java` created its
`FlutterTextureView` with the default `isOpaque()==true`; the window's
"transparent" area composited as a dark box behind bubble + pill. Fix:
`textureView.setOpaque(false)`.

## What was NOT done (deliberate)
- **No watchdog/periodic service restart.** User asked for one ("service
  restarts itself randomly or at a fixed interval") as a hang mitigation — the
  hang's root cause is fixed instead. If device testing still shows hangs,
  revisit; a restart loop papers over whatever is left and would drop offers
  mid-read.
- Uber parsing investigation still DEFERRED (per HANDOFF-2026-07-16); the
  earlier Uber patches (contentDescription fallback, active-root walk, depth
  60) are kept intact and now also benefit from the background thread.

## Verification
- `flutter analyze` — clean.
- `flutter build apk --debug` — Java patches compile.
- `flutter test` — 97 passed.
- Device testing pending: `docs/MANUAL_TESTS.md` OV.1–OV.6 (new section).

## Files changed
- `third_party/flutter_accessibility_service/.../AccessibilityListener.java`
  — background HandlerThread + event coalescing; removed TEMP diagnostic
  double-walk; bounded LruCache.
- `third_party/flutter_overlay_window/.../OverlayService.java`
  — `setOpaque(false)` on the texture view.
- `docs/MANUAL_TESTS.md` — OV-rows added.
