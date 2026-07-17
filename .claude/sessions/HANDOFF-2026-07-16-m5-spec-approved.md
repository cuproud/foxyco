# HANDOFF 2026-07-16 — M5 spec approved, implementation next

## Where we are

M5 milestone brainstormed + spec approved + committed:
`docs/superpowers/specs/2026-07-16-m5-polish-and-control-design.md` (commit 8af75d0)

Four features (Uber investigation explicitly DEFERRED to after M5):

1. **Pill size live** — bug: `lib/ui/overlay/overlay_entry.dart` hardcodes
   `size: PillSize.small`, ignores `payload.size`. Fix: render payload.size,
   scale window box per size (small 300×72, medium 324×84, large 348×100 dp,
   MUST stay <360dp wide), live preview in Settings.
2. **Persistent logs** — new `FoxLog` service, file in app documents dir,
   1MB rotation ×2 files, buffered writes, fail-soft. NEW dep: `path_provider`
   (approved in spec). Settings → Logs viewer + clipboard export + clear.
3. **Driver profile** — `DriverProfile` domain model, SharedPreferences JSON
   (`foxyco.profile.v1`), Settings form (name/make/model/year/plate, color
   swatches, type chips), Home hero card (greeting + vehicle line +
   CustomPaint side-view silhouette per type tinted vehicleColor, entrance
   fade+slide + sheen loop, respect disableAnimations). Card only when name
   non-empty.
4. **Manual start** — add `WatchStatus.stopped`; boot lands stopped (not
   watching); Start Monitoring button on dashboard gates everything; Stop
   tears overlay down; NEVER persist running state across restarts;
   pause/resume unchanged on top.

## Next step in new session

Invoke `superpowers:writing-plans` skill with the spec as input → implementation
plan → then implement. Spec user-approved; no re-brainstorm needed.

## Uber status (deferred, do NOT lose)

- Latest device test 2026-07-16 FAILED: 2 offers, bubble up, service on,
  zero parses, no useful logs. Test ran the NEW build including the
  uncommitted `third_party/.../AccessibilityListener.java` patches
  (contentDescription fallback, all-windows walk, depth 60, FoxyCoWin
  diagnostic). Patches ran, still missed — window-walk approach itself
  suspect. Investigation resumes after M5. Note `if (true) return;` TEMP
  hack + FoxyCoWin diag logs still in AccessibilityListener.java.
- M5 item 2 (persistent logs) is partly motivated by this — next Uber test
  should produce durable evidence.

## Working tree

Uncommitted changes predate this session (splash/branding, overlay_service,
verdict_pill, settings_screen, AccessibilityListener.java Uber patches).
Leave them; they're live work-in-progress, some device-tested.
