# DESIGN — fix "nothing parses" + "tap won't foreground" (2026-07-13)

Two independent systems are broken. Root causes found by reading the vendored
plugin source + on-device dumpsys/logcat, not guessing.

## Problem A — NOTHING parses (Uber, Lyft, Hopp — all)

### Root cause (confirmed on device)
`FlutterAccessibilityServicePlugin.onListen()` only registers the
`AccessibilityReceiver` **if `Utils.isAccessibilitySettingsOn(context)` is true**.
On this device that check returns **false** (logged:
`onListen called; isAccessibilitySettingsOn=false`) even though:
- the service is enabled in user-0 settings,
- it is bound + connected (`dumpsys accessibility` shows it),
- it is firing constantly (`accessibility_event ... total=7813` broadcasts).

So the receiver is never registered → every broadcast is dropped → **zero**
`ScreenRead`s ever reach Dart. The parser never runs. Uber isn't special; the
whole pipeline is dark.

### Fix
1. **Remove the `isAccessibilitySettingsOn` gate in `onListen`** — register the
   receiver + start the service unconditionally. Safe: `onAccessibilityEvent`
   only broadcasts when the OS-bound service is actually running, so an
   always-registered receiver just sits idle when the service is off. The gate
   was a redundant guard whose false-negative bricked everything.

### Supporting fixes (make the now-flowing stream usable)
2. `accessibility_watcher.reads()` — the debounce **cancel-and-reset on every
   event** never settles on a live screen (map panning / countdown fire faster
   than 250 ms) → it would emit nothing even with events flowing. Switch to a
   **trailing throttle** (arm the timer once, never cancel) so the latest frame
   flushes at least once per interval. *(done)*
3. `offer_watcher` — clearing the pill on the first non-offer frame made it
   blink out in <1 ms. **Debounce the clear** (3 s grace, cancelled by any offer
   read). *(done)*
4. Uber's card: TEST FIRST whether it rides in the active window (most bottom
   sheets do). Keep `collectSamePackageWindows` **disabled** until proven needed;
   if needed, re-enable **bounded** (node cap, no per-node logging) — the
   unbounded sweep produced a 98 KB/event payload and jammed the main thread.

## Problem B — tap bubble won't foreground FoxyCo

### Root cause (confirmed)
`bringHostAppToFront()` **never runs** — no `FoxyCoNative` log despite 8 taps.
The tap's `shareData(openApp)` loops through the messenger channel back to the
overlay isolate's own listener; the native interception point in
`OverlayService`'s MESSENGER handler isn't on that path. The main isolate's
`OverlayController._onAction(openApp)` is a no-op (`break`).

### Android technique (researched, Android 14/15/16)
Holding `SYSTEM_ALERT_WINDOW` **and having a visible overlay window** (we have
the bubble) is a valid background-activity-launch exemption. So `startActivity`
from our own process IS allowed on 14/15/16 — the launch was never the problem,
*calling it* was.

### Fix
Trigger the launch over the **OVERLAY method channel** (`x-slayer/overlay`) — the
exact path `resizeOverlay`/`moveOverlay` already use successfully (the pill
resizes, proving it works). No cross-isolate message loop.
1. `OverlayService.flutterChannel` handler: add a `bringToFront` method →
   `bringHostAppToFront()`.
2. `FlutterOverlayWindow.bringHostToFront()` Dart wrapper → invoke `bringToFront`.
3. `overlay_entry._onBubbleTap` → call it directly (keep `shareData(openApp)`
   too, for future deep-linking hooks).
`bringHostAppToFront()` already has the explicit-MainActivity fallback for the
null-launch-intent multi-user case.

## Verify (one pass, minimal cycles)
Deploy to **user 0** (gig apps live there, not the dual-app 95). Overlay granted
+ a11y enabled in user 0. Then:
- foreground Hopp/Uber → logcat `read pkg=...` now non-empty, verdict logged.
- tap bubble → `bringToFront` → FoxyCo comes forward.
