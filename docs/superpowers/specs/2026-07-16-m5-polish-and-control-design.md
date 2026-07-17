# M5 — Polish & Control: live pill size, persistent logs, driver profile, manual start

**Date:** 2026-07-16
**Status:** Approved (user brainstorm session)
**Scope note:** Uber detection reliability investigation is explicitly deferred — the
2026-07-16 `AccessibilityListener.java` patches ran on-device and still missed offers;
that investigation resumes after this milestone. Nothing here touches parsing logic.

## 1. Pill size — live effect

**Bug:** `lib/ui/overlay/overlay_entry.dart` hardcodes `size: PillSize.small` when
building `VerdictPill`, ignoring `payload.size` (the setting already travels in
`OverlayPayload` — see `overlay_controller.dart` `showFromOffer`). The overlay window
box is also fixed at 300×72dp, sized only for the small pill.

**Fix:**
- Overlay isolate renders `VerdictPill(size: payload.size)` and resizes the window
  per size. Window boxes (dp): small 300×72, medium 324×84, large 348×100.
  **Constraint:** width must stay under 360dp (narrowest target screen) or the
  native X-clamp pins the window mid-screen and it can't be dragged to an edge
  (see comment at `overlay_entry.dart` `_pillBox`).
- Settings screen: live `VerdictPill` preview widget below the Small/Medium/Large
  selector, rendering a sample payload at the selected size — change is visible
  instantly in-app without waiting for a real offer.
- A pill already on-screen when the setting changes keeps its size; the **next**
  offer uses the new size. (Real pills live seconds; re-pushing a live payload
  across the isolate is not worth the plumbing.)
- The demo/simulate pill respects the setting (it already flows through
  `showOffer`, so it inherits the fix once `overlay_entry` stops overriding).

## 2. Persistent logs

**Now:** `debugPrint` only — lost on process death, invisible in release builds.

**New `FoxLog` service** (`lib/services/fox_log.dart`):
- Append-only text file `logs/foxyco.log` under the app documents directory.
  **New dependency:** `path_provider` (first-party flutter.dev plugin; only
  desktop platform shims are currently transitive — the Android implementation
  is not). Justification: only sanctioned way to resolve the app documents dir;
  no reasonable alternative.
  Survives `adb install -r` updates, app/service restarts, reboots. Dies only on
  full uninstall (accepted — option A).
- Line format: `2026-07-16T21:04:11.123 [tag] message` — tags mirror existing
  debugPrint prefixes: `watch`, `parse`, `overlay`, `status`, `error`.
- Rotation: at 1 MB, roll to `foxyco.log.1` (delete old `.1`), keep two files max.
- Buffered writes (small in-memory queue, flush on a short timer and on append
  after idle) so hot a11y-event paths never block on disk I/O.
- Fail-soft: any I/O error is swallowed (a logger must never crash the pipeline);
  off-device tests see a no-op.
- **Wire-in points** (alongside, not replacing, existing `debugPrint`s):
  raw screen reads (throttled — one line per emitted `ScreenRead`, not per raw
  event), parse hit/miss + platform, verdicts + payload summary, overlay
  show/clear, watch-status changes, caught errors.
- **Settings → Logs tile:** opens a viewer screen (scrollable tail of current
  file, newest at bottom), with copy-to-clipboard export (no `share_plus` in
  the project; not worth a new dep — clipboard covers the debug loop) and a
  Clear button (truncates both files, confirm dialog).

## 3. Driver profile

**Model:** `DriverProfile` in `lib/domain/` — fields: `name`, `vehicleMake`,
`vehicleModel`, `vehicleYear`, `vehicleColor` (a `Color` from a fixed palette
picker), `licensePlate`, `vehicleType` (enum: sedan, suv, hatchback, pickup,
van, motorbike). All optional strings default empty; profile "complete enough
for hero card" = non-empty `name`.

**Persistence:** single SharedPreferences JSON blob, same pattern as
`FoxSettings`/`OfferLog` (`foxyco.profile.v1`), Riverpod `Notifier` +
provider in `lib/ui/settings/` or `lib/services/` matching existing layout.

**Settings → Profile section:** simple form — text fields (name, make, model,
year, plate), color palette picker (fixed swatch row: white, black, silver,
gray, red, blue, green, yellow/gold, orange, brown), vehicle-type choice chips.
Saves on edit (no explicit save button), matching settings screen's live-apply
feel.

**Home dashboard hero card:** shown at top only when `name` is non-empty.
- Greeting by name (time-of-day aware: "Good morning, Vamsi" style).
- Vehicle line: "Red 2022 Toyota Camry · ABC-123" (skips empty parts cleanly).
- Vehicle art: side-view silhouette per `vehicleType`, drawn with `CustomPaint`
  (one painter, six path variants), filled with `vehicleColor` + simple shading
  (darker underside, lighter roofline, window tint). No bundled images, no
  network. Option A from brainstorm — real-photo APIs rejected (keys, cost,
  offline drivers).
- Animation, subtle: one-shot entrance fade+slide on first build, and a slow
  looping sheen sweep across the card (low-opacity gradient, long period).
  Respect reduced-motion (`MediaQuery.disableAnimations`) — static card then.
- No profile → no card; dashboard renders exactly as today.

## 4. Manual monitoring start

**Now:** `DashboardController.build()` defaults to `WatchStatus.watching`;
`OverlayController` mirrors status with `fireImmediately: true` — bubble
auto-appears the moment permissions exist. User never asked for it.

**Change:**
- Add `WatchStatus.stopped` to the enum (`dashboard_state.dart`).
- Boot state: permissions granted → `stopped` (not `watching`); missing →
  `blocked`. `refreshPermissions()` maps "all granted + not paused + not
  already watching" → `stopped` instead of auto-`watching`; an explicit
  running state (`watching`/`paused`) survives a permissions refresh.
- Dashboard: prominent **Start Monitoring** button when `stopped`. Tap →
  `watching`: overlay bubble appears (existing status listener), parse gate
  opens (`offer_watcher` already drops reads unless `watching` — the gate at
  `_onRead`). A **Stop** affordance while watching/paused → back to `stopped`,
  overlay torn down (existing `hide()` path).
- **Always boots `stopped`** — never persists/restores a running state across
  process death (option A: user always in control).
- Pause/resume (bubble long-press, drop-to-X, Home pause) unchanged, layered
  on top: pause is a temporary mute *while running*; stop is fully off.
- Accessibility service itself stays OS-managed (it starts when the user
  enables it in system settings — Android controls that lifecycle); FoxyCo's
  *use* of its events is what Start/Stop gates. Onboarding copy stays truthful:
  granting permission no longer summons the bubble.

## Testing

- `flutter analyze` clean; existing test suite green.
- Unit: `FoxLog` rotation + fail-soft; `DriverProfile` (de)serialization;
  dashboard status transitions (boot→stopped, start→watching, stop→stopped,
  blocked precedence); overlay controller maps `stopped` → hide.
- Widget: settings pill preview resizes across the three sizes; hero card
  appears only with a name; Start button gates the dashboard.
- Manual (device, per docs/MANUAL_TESTS.md convention): pill size change
  visible on next simulated offer at exact sizes; logs survive `adb install -r`;
  bubble does NOT appear after grant until Start tapped.

## Out of scope

- Uber detection investigation (deferred, next).
- Real vehicle photo APIs, profile pictures.
- Log survival across uninstall (option B rejected).
- Remembering running state across restarts (option B rejected).
