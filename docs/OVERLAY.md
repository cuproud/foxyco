# FoxyCo — Overlay Spec + Screen Research

The overlay is the product. It must sit in dead space, never cover the platform's own controls,
and show only what the platform doesn't: the verdict + true $/km.

---

## Part 1 — How the target apps lay out their request screens (research)

Sources at bottom. Findings drive every placement decision below.

### Uber Driver (rideshare) — base platform
- Request = **bottom-sheet card**, lower ~40% of screen. Map fills the top half.
- Shows: trip-type chips (UberX / Exclusive), countdown, **big bold fare top-left**, rider rating,
  boost chip, pickup `4 mins (0.8 km) away`, dropoff `15 mins (4.3 km) trip`, full-width Accept.
- **Top-right has an X close.** ← must NOT be covered.
- ⚠️ **Upfront fare/destination only shown if acceptance rate stays high enough.** If the driver
  drops below Uber's gate, Uber hides the numbers → nothing to parse. FoxyCo must degrade gracefully.

### Hopp — base platform
- **`✕ Decline` black pill floats top-right**, over the map. Green route pill `46.3 km · 34 min`.
- Bottom card: `Hopp` + `Card` chips, **`$15.65` (NET, tax included)** with a **green underline bar**,
  rider chip, pickup `3 min · 1.1 km`, dropoff `34 min · 46.3 km`, full-width green Accept.
- **Pay = NET** (already smarter than Uber's gross). Distances split pickup vs trip, same as Uber.

### DoorDash / delivery (deferred to M6)
- Offer = bottom sheet: guaranteed pay, distance, item count, Accept/Decline slider. Pay + distance
  on one screen every time. Reliable, but not a base platform — Uber + Hopp screenshots are the base.

### Maxymo (the reference competitor)
- "Trip optimizer overlay." Uses `Display over other apps` (draw) + **Accessibility Service** (read
  the offer). Color-coded bar in the dead zone, never over the Accept button. Auto-accept/decline
  optional. **Android-only** — iOS blocks overlays + accessibility automation entirely. (FoxyCo is
  Flutter, but the Android capabilities it leans on are identical — see Part 3.)

### The safe zone (conclusion)

```
┌───────────────────────┐  status bar
│                    [X] │  ◄─ platform decline / X — KEEP CLEAR
│  ╭─ FoxyCo pill ─╮     │  ◄─ pill sits HERE: top area, but DROPPED
│  ╰───────────────╯     │     down from the very edge to clear [X]
│      MAP  (top ~50%)   │
├───────────────────────┤
│  $14.50   UberX        │  ◄─ platform card — untouched
│  ★4.9   25min · 12mi   │
│  ┌─────────────────┐   │
│  │     ACCEPT      │   │  ◄─ Accept — NEVER covered
│  └─────────────────┘   │
└───────────────────────┘
```

Rules that fall out:
1. Pill lives in the top map region, **dropped below the top edge** so it clears the platform's
   top-right X/decline.
2. Never render over the bottom card or the Accept button.
3. Don't repeat the platform's numbers — show verdict + $/km (the value-add). Total km is shown
   because both apps split pickup vs dropoff; FoxyCo shows the sum (neither app does).
4. Single line only. Two lines = covering something.

---

## Part 2 — The two overlay components

### Pill (the verdict)
- **Content (MVP):** `⬤ GOOD · 8.4 km · $12`  — dot color = verdict, total km, payout.
- **Position:** top region, dropped from edge (default offset configurable). Draggable; remembers
  last position (SharedPreferences). Clamped so it can't sit over the known X/Accept zones.
- **Size:** S / M / L (driver picks; L for glanceability, S to stay out of the way).
- **Tap:** expands to a fuller (still compact) breakdown card. Tap again / timeout collapses.
- **Lifecycle:** appears on offer detect, auto-dismiss after configurable timeout (default ~12 s,
  roughly the platform's own decision window).

### Bubble (the control)
- Always-on draggable dot (Maxymo / Messenger style), snaps to screen edge.
- Color = last verdict, or neutral when idle → ambient status without opening anything.
- **Tap:** open FoxyCo (jump to filters/settings fast).
- **Long-press:** pause / resume watching (also stops the heavy accessibility work).
- Survives across apps; it's the persistent handle to FoxyCo while driving.

---

## Part 3 — How it's built (Flutter + native Android plugins)

FoxyCo is Flutter, but overlays and reading other apps are Android system features. Two maintained
plugins wrap the native APIs so we write Dart, not Kotlin, for the bulk of it. The plugins
themselves do the native `WindowManager` / `AccessibilityService` work under the hood.

### Drawing the pill/bubble — `flutter_overlay_window`
- Wraps `SYSTEM_ALERT_WINDOW` ("Display over other apps") + `TYPE_APPLICATION_OVERLAY` (API 26+).
- Permission can't be granted silently: `FlutterOverlayWindow.requestPermission()` opens the system
  settings page. Check with `isPermissionGranted()`.
- Show the overlay: `FlutterOverlayWindow.showOverlay(...)` with size, alignment, and
  `flag: OverlayFlag.defaultFlag` (lets touches pass through to the platform app except on our
  widget). Update via `shareData`; close via `closeOverlay()`.
- **The overlay UI is a separate entrypoint** you register in `main.dart`:

  ```dart
  @pragma('vm:entry-point')
  void overlayMain() {
    runApp(const FoxyOverlayApp()); // renders pill + bubble
  }
  ```

  It runs in **its own isolate** — no shared memory with the main app. This is the key Flutter
  difference from a native build. Communicate across the boundary:

  ```dart
  // main isolate → overlay isolate
  await FlutterOverlayWindow.shareData({'verdict': 'good', 'totalKm': 8.4, 'payout': 12});

  // inside the overlay isolate
  FlutterOverlayWindow.overlayListener.listen((data) {
    // rebuild the pill from the map
  });
  ```

- Dragging: the plugin supports moving the overlay; persist the final x/y offset in SharedPreferences
  and restore on next show. Clamp to the safe zone from Part 1.
- Both pill and bubble are ordinary Flutter widgets, so they share the `ui/theme/` design tokens
  with the rest of the app — one visual language.

### Reading offers — `flutter_accessibility_service`
- Wraps `AccessibilityService`. Declare it in `AndroidManifest.xml` with an
  `accessibilityservice` meta-data config: `accessibilityEventTypes` =
  `typeWindowStateChanged|typeWindowContentChanged`, `packageNames` = `com.ubercab.driver` + Hopp's
  package, `canRetrieveWindowContent=true`.
- Request permission: `FlutterAccessibilityService.requestAccessibilityPermission()` (opens system
  settings — user must toggle it on). Onboarding must explain **why** (Play policy, AUDIT #1).
- Listen: `FlutterAccessibilityService.accessStream.listen((event) { ... })`. Each event carries the
  screen's nodes — `event.nodesText` / node bounds / package name.
- On event: filter to the target package, pull the text nodes, hand to the matching `OfferParser`
  (regex per REFERENCE_ANALYSIS.md), build an `Offer`.
- **Debounce:** content-changed fires a lot; parse on a short debounce + dedupe identical offers
  (battery — AUDIT #4).
- **Fragility:** selectors break when Uber/Hopp update. Keep each platform parser isolated, tag it
  with the app version it was tuned against, and log the raw node dump behind a debug flag so
  re-tuning is fast. See AUDIT.md.

### Keeping it alive
- `flutter_overlay_window`'s overlay + the accessibility service keep FoxyCo's watching alive while
  the driver is in Uber/Hopp. If a persistent foreground notification is needed for the watch loop,
  add `flutter_foreground_task`; otherwise the accessibility service + overlay suffice. Decide at M3.

### Auto-accept (💤 DEFERRED — read AUDIT first)
- Technically possible: `flutter_accessibility_service` can `performAction` a click on the Accept
  node. **This is the ToS-risky, deactivation-risky feature. NOT in MVP.** FoxyCo is a
  *read-and-advise* tool first. If ever added: opt-in, off by default, explicit warning. See AUDIT.md.

---

## Sources

- Uber request screen / upfront-details behavior — Uber Drivers Forum & Medium rideshare guides:
  https://www.uberpeople.net/threads/ride-request-screen-detail-question.500633/ ·
  https://medium.com/rideshare-driver/how-to-decide-which-rides-to-accept-and-which-ones-to-decline-and-or-cancel-a54baae3382c
- Uber official driver app basics — https://www.uber.com/us/en/drive/basics/
- Maxymo overlay mechanics (overlay + accessibility) — https://maxymoapp.com/ ·
  https://middletontech.com/blog/apps/the-maxymo-app/ ·
  https://maxymo.zendesk.com/hc/en-us/articles/27419482520983-Overlay-Permission-Assist
- Plugins — https://pub.dev/packages/flutter_overlay_window ·
  https://pub.dev/packages/flutter_accessibility_service
