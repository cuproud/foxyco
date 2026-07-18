# M5 — Polish & Control (2026-07-17)

**Branch:** `m5-polish-and-control` · **Plan:** `docs/superpowers/plans/2026-07-17-m5-polish-and-control.md`
**Spec:** HANDOFF-2026-07-16-m5-spec-approved.md (approved)

## What shipped

### 1. Pill size takes effect (Tasks 1)
- `overlay_entry.dart`: `_pillBoxFor(PillSize)` — small 300×72, medium 324×84,
  large 348×100 dp. Window resizes per offer's `payload.size`; all widths stay
  under the 360dp native X-clamp so the pill remains draggable.
- Overlay `VerdictPill(payload: payload)` — null size falls through to
  `payload.size` (was hardcoded `PillSize.small`).
- Settings: live `VerdictPill` preview under the size selector (sample GOOD
  payload at the selected size).

### 2. Persistent file logs (Tasks 2–3)
- NEW `lib/services/fox_log.dart` — `FoxLog`: buffered (2s timer), rotated at
  1 MB to `foxyco.log.1` (two files max), fail-soft everywhere, no-op
  off-device. **Sync writes** — required so FoxLog works under widget-test
  FakeAsync; writes are small and buffered so this is safe on device too.
  Provider disposes cleanly (cancels flush timer) so tests don't leak timers.
- NEW dep: `path_provider` (docs dir; only new dependency, per spec).
- Wired into: offer_watcher (read/parse/miss/clear/error), overlay_controller
  (show), dashboard_controller (every status change).
- NEW `lib/ui/settings/logs_screen.dart` — tail viewer (newest at bottom),
  copy-to-clipboard export, confirm-gated Clear. Settings → "View logs" card
  (plain InkWell row, NOT ListTile — ListTile needs a Material ancestor the
  `_Card` DecoratedBox doesn't provide; caused test failures first try).

### 3. Driver profile (Tasks 4–6)
- NEW `lib/domain/driver_profile.dart` — pure Dart, ARGB int color,
  `VehicleType` ×6, 10-swatch `palette`, `vehicleLine` ("Red 2022 Toyota
  Camry · ABC-123"). Color only appears in `vehicleLine` when real vehicle
  info exists (default White swatch alone ≠ a vehicle — caught by test).
- NEW `lib/ui/settings/profile_controller.dart` — `foxyco.profile.v1` blob,
  live-apply, mirrors SettingsController.
- Settings: `_ProfileForm` at top — text fields (seed-once from async load),
  color swatches, body-style chips.
- NEW `lib/ui/home/profile_card.dart` — `ProfileCard` (hidden until name set;
  bottom padding lives inside the card so the home list doesn't double-space)
  + `VehiclePainter` (six fraction-scaled silhouettes). Time-aware greeting,
  entrance fade+slide, 6s sheen loop; both skipped under
  `MediaQuery.disableAnimations`.

### 4. Manual monitoring start (Task 7)
- `WatchStatus.stopped` added. Boot ALWAYS lands stopped (or blocked) — a
  running watch is never persisted (spec option A).
- `startMonitoring()` / `stopMonitoring()`; `togglePause` no-ops while
  stopped; `stopWatching` (bubble drop-to-✕) now routes to full stop;
  `refreshPermissions` keeps an explicit watching/paused, otherwise maps
  granted+idle → stopped. Permission re-grant after a revoke lands on
  stopped (no auto-resume — behavior change from M4, matches spec).
- Overlay `_applyStatus`: stopped → hide (same teardown as paused/blocked).
- Home hero button is now the Start/Stop outer gate ("Go Live" ↔ "Stop";
  paused still shows "Stop" since paused = running). Hero status text for
  stopped: "Ready when you are". Pause stays on bubble long-press only.

## Verification
- `flutter analyze` — clean.
- `flutter test` — 117 passed (was 97 pre-M5; +20 new/updated).
- Device verification pending: MANUAL_TESTS M5.1–M5.10 (plus OV.1–OV.6 from
  the bug batch still awaiting user's device pass).

## Tests updated for the new boot-stopped contract
- `widget_test.dart` — boots "Ready when you are"; Go Live → Stop round-trip.
- `overlay_controller_test.dart` — bubble no longer auto-raises on boot;
  startMonitoring raises it; new stopped-hides test; bubble drop → stopped.
- `dashboard_resilience_test.dart` — re-grant lands stopped, not watching.
- `offer_watcher_test.dart` — container helper calls startMonitoring.

## Loose ends / follow-ups
- Uber detection investigation — still deferred (out of M5 scope).
- FoxLog `debugPrint` traces alongside file log: the kDebugMode read-spam
  trace in offer_watcher still slated for removal before release.
- Next: superpowers:finishing-a-development-branch (merge decision with user).
