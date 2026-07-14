# HANDOFF — M3 rework device-verified (2026-07-13)

**Read the prior handoff `.claude/sessions/HANDOFF-2026-07-12-m3-parsing-overlay-rework.md`
first for the rework design. This one records what got VERIFIED ON DEVICE and
the 2 real bugs left.**

## TL;DR
The strict-parsing + overlay-lifecycle rework WORKS on real offers. Lyft + Hopp
verified end-to-end on a live Galaxy S24. Two open items: (1) Uber offer cards
never reach the accessibility service, (2) tap-bubble doesn't foreground the app.

## VERIFIED ON DEVICE (real offers, not fixtures)
- **Lyft**: 3 real offers parsed correct — `$4.88/3.7km`, `$10.83/10.1km`,
  `$7.04/5.5km`. Bonus + `$/hr est. rate` lines correctly skipped, 2 legs summed,
  verdict + pill drawn.
- **Hopp**: real offer `$8.28 (NET)/6.5km` parsed correct, pill drawn.
- **Pill instant-clear**: `clear: offer left screen` fires the moment the card
  closes → pill gone. Stale-pill bug DEAD.
- **Strict rejection**: every Lyft Ride-Finder / scheduled-ride / Turbo-banner
  dump, Hopp "Scheduled Rides available" home, Uber online/searching map, and a
  Lyft safety survey → all correctly `drop: parse null`. False positives DEAD.
- **Pause/Resume + drop-to-bottom**: bubble drag-to-bottom fires `stopWatching`
  → dashboard flips to Paused (verified — it's what left it stuck paused mid-
  session; Resume on Home un-pauses).
- `flutter analyze` clean, `flutter test` **67/67 green**, debug APK builds
  (native OverlayService.java changes compile).

## OPEN BUG 1 — Uber offers never parse (accessibility, NOT regex)
Real Uber card (see screenshots below) is EXACTLY our regex format:
`$12.38 · UberX Exclusive · ★4.91 · 2 mins (0.2 km) away · 21 mins (9.5 km) trip · Accept`.
The parser WOULD handle it. BUT in a full session, ZERO Uber reads ever contained
`$`/`km`/`Accept` — only the background map (`Trip Planner`, `1-2 min`,
`Finding trips`). **The offer card window is not reaching our accessibility
service.** This is the exact limitation the 07-12 handoff feared.
- NEXT: get a LIVE Uber offer up, run `adb shell uiautomator dump --user 95` and
  inspect — does the a11y tree even contain the `$12.38`/`Accept` nodes?
  - If YES → our service/flatten drops it (fix: window handling; a11y config
    already has `flagRetrieveInteractiveWindows`). Maybe the offer is a separate
    window the plugin doesn't traverse.
  - If NO → Uber renders the card in an a11y-hostile surface; parser can't help.
    Document as a known Uber gap (Lyft/Hopp still deliver value).
- Real Uber offer screenshots (WSL mount works): `/mnt/c/Users/vamsi/Downloads/`
  `Screenshot_20260713_084115_Uber Driver.jpg`, `_084127_`, `_084146_`, `_083129_`.

## OPEN BUG 2 — tap bubble doesn't foreground FoxyCo
Native `bringHostAppToFront()` added in OverlayService.java (intercepts `openApp`
in the overlay→native message handler, launches `getLaunchIntentForPackage`).
Tap fires `openApp` (seen in log) but app doesn't come forward. Diagnostic
logging is IN (tag `FoxyCoNative`, logs launchIntent + startActivity). NEXT:
tap bubble, `adb logcat -d | grep FoxyCoNative`:
- no line → interception not reached (message routing).
- "launchIntent=null" → multi-user (user 95) launch-intent problem.
- "startActivity called" but nothing → Android 16 background-activity-launch
  block; needs a full-screen-intent notification or focusable-overlay approach.
- **Remove the `FoxyCoNative` debug logs before release.**

## NOT yet visually confirmed
Drag-clamp (bubble stays on-screen at edges — bug1 7). Just eyeball it.

## DEVICE / TOOLING (important — env is a Hyper-V VM, NO USB passthrough)
- **adb only works over WIRELESS (USB tethering gives the route).** USB cable
  alone is invisible to this VM. Port ROTATES every session:
  `adb connect 192.168.2.10:<port>` — get port from phone Settings → Developer
  options → Wireless debugging. (Seen this session: 45525, 33645.)
- **App runs under Android user 95** (secondary/Secure-Folder profile). `pm`,
  `am start`, `uiautomator dump` all need `--user 95`. Package = `com.foxyco.app`
  (the DEBUGGABLE build — ignore any release install).
- flutter: `/home/vamsi/development/flutter/bin/flutter`
- adb: `/home/vamsi/android-sdk/platform-tools/adb`
- Build+install: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- Live node capture: `adb logcat -v tag | grep -E "FoxyCo\[watch\]|FoxyCoNative"`
- Package names CONFIRMED on device: `com.ubercab.driver`, `ee.hopp.driver`,
  `com.lyft.android.driver` (registry + res/xml correct).

## Real captured node fixtures (paste into tests if useful)
- Lyft offer: `$10.83 | Incl. CA$2.50 in bonuses | $25.99/hr est. rate for this ride | 3 mins • 0.6 km | Finch & Kenneth, North York | 22 mins • 9.5 km | Denison & Woodbine, Markham | Pay & matching info in help centre | Jenny | 4.9 | Lyft | Accept`
- Hopp offer: `Decline | Wait and Save | Card | $8.28 (NET, tax included) | ...`
- Lyft scheduled (must reject): `... 11 rides available | SUGGESTED SCHEDULED RIDE | $9.71 Lyft ride | 17 mins • 10.7 km | 9:15 a.m. ...`

## Nothing committed. Rework lives in the working tree with M2 + prior M3.

---

## UPDATE 2026-07-13 (later session) — both open bugs fixed + pill lifetime tuned

**Both OPEN BUGs above are resolved on device; a third issue (pill lifetime) found and fixed.**

### BUG 1 (Uber never parsed) — root cause was a CRASH, not the a11y tree
The accessibility service was crash-looping on every connect: `NullPointerException`
at `AccessibilityListener.onServiceConnected` — upstream plugin code force-attached
a `FlutterView` to the plugin's own overlay engine (entry point `accessibilityOverlay`),
which this app never defines → null → NPE → service died and delivered ZERO events.
Not a permission/regex/window issue. Fixed: `onServiceConnected` now wires the overlay
view only if that engine exists (we don't use it). Also removed the fragile
`isAccessibilitySettingsOn` gate that was blocking the receiver. Parsing now works live.

### BUG 2 (tap bubble) — FIXED
Tap now foregrounds FoxyCo. The working path is `FlutterOverlayWindow.bringHostToFront()`
called DIRECTLY on the overlay method channel (same reliable path as `resizeOverlay`),
not the `openApp`-action round-trip that looped back and never reached native. SAW +
a visible bubble make the launch legal. **Verified on S24.**

### NEW: pill lifetime (found on device this session)
Two findings, both fixed in `lib/services/accessibility/offer_watcher.dart`:
1. **Pill auto-closed after ~5 s while the offer was still on screen.** Live cards
   (map / countdown) fire mostly *partial* frames where the full parse fails, so
   successful parses dried up and the old 3 s `clearGrace` timer aged the pill out
   under a live card.
2. **On accept/decline/dismiss the pill should close promptly.**

Fix: the pill's life is now gated on the card's **Accept/Match affordance**
(`ParserPatterns.hasAcceptAction`) — present the whole time the card is up (even on
partial frames), gone the instant the driver acts and the app returns to the map.
A failed full-parse while the affordance is still present KEEPS the pill (cancels any
pending clear); the affordance leaving arms a short `clearGrace` (now **1 s**) so a real
dismiss clears promptly without lingering. Overlay-isolate `_dismissAfter` is a
dropped-message safety net only.

- Tests: added `keeps the pill while the card is up but the full parse fails` and
  `clears promptly once the offer card (affordance) is gone` to
  `test/offer_watcher_test.dart`. **`flutter test` 70/70 green, `flutter analyze` clean.**
- Docs updated: `docs/OVERLAY.md` (Lifecycle), `docs/MANUAL_TESTS.md` (rows 2.6, 3.13,
  2.8/3.16 marked verified, new M3-lifetime rows 3.18–3.21).

### Still to verify on device (couldn't this session — no adb device attached)
- No Android device was attached to adb this session (`adb devices` empty) and the
  debug-APK build was blocked, so the pill-lifetime fix is code-complete + unit-tested
  but NOT yet device-verified. Re-attach the S24, build+install, run rows 3.18–3.21.
- Debug traces (`FoxyCo[watch]`, `FoxyCoNative`) still in — strip before release.
