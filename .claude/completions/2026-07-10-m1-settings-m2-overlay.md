# 2026-07-10 — M1 Settings + M2 Overlay

## What shipped

### Branding
- Clean, text-free **fox-head launcher icon** (cropped from `foxyco_icon_car_a`), full-bleed
  adaptive fg/bg, verified against circle + squircle masks. Replaced the busy text render.
- **Splash** (`flutter_native_splash`) on dark base + Android-12 variant.
- Home empty-state mascot uses the icon asset (no emoji).
- App label fixed to **FoxyCo** (`AndroidManifest.xml`).

### M1 — Settings + verdict engine
- `domain/thresholds.dart`, `domain/decision_engine.dart` — pure Dart. Inclusive GOOD, exclusive
  BAD, OK band `[badBelow, goodAtOrAbove)`. Defaults GOOD ≥ 1.50 / BAD < 1.00.
- `ui/settings/` — sliders + **live verdict preview** (drags a sample $/km through the real
  `DecisionEngine`), band clamps so it can't invert. Wired to `/settings`; Home gear navigates.

### M2 — Overlay (code-complete, device verify pending)
- `domain/overlay_payload.dart` / `overlay_action.dart` / `overlay_control.dart` — `kind`-tagged
  primitive wire format for the separate overlay isolate. Fails safe on garbage.
- `ui/overlay/verdict_pill.dart` (S/M/L, shape+color+word), `fox_bubble.dart` (tap/long-press),
  `overlay_entry.dart` (`FoxOverlayApp`, routes messages, 12s auto-dismiss, bubble+pill Stack).
- `services/overlay_service.dart` — wraps `flutter_overlay_window`; `domain/` stays plugin-free.
- `ui/overlay/overlay_controller.dart` — routes bubble gestures back to the dashboard (pause echo).
- `main.dart` — `@pragma('vm:entry-point') overlayMain()`.
- Manifest: `SYSTEM_ALERT_WINDOW` + special-use FGS; **no INTERNET** (offline by design).
- Home **Debug → Simulate offer** rotates GOOD/OK/BAD.

### Tooling
- `scripts/build.sh` — uniquely-named APKs (`FoxyCo-v1.0.0+N-release-STAMP.apk`) in `dist/`,
  `--bump` auto-increments the build number. Fixed the `--release` flag bug.

## Verification
- `flutter analyze` → No issues found.
- `flutter test` → 31 passing (DecisionEngine branches, Thresholds, settings widget/clamp,
  OverlayPayload round-trip/fail-safe, OverlayController permission-gate/rotation/pause-echo,
  FoxBubble gestures/paused state).

## Not done (deferred, tracked in ROADMAP)
- ⏳ **Device run of the overlay** — plugin overlay can't run in `flutter test`; needs a real
  device: `./scripts/build.sh --bump`, install, tap Simulate offer, confirm pill floats + clears
  Accept/Decline on 3 devices.
- 💤 SharedPreferences persistence (thresholds + pill position) — M3.
- 💤 Simplified fox-head icon refinement, if the current crop needs it.

## Next
- M3 — Uber + Hopp parser (the hard milestone). Real offer data replaces the debug simulator.
