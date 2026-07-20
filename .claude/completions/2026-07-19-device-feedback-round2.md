# 2026-07-19 — Device feedback round 2: UX fixes, filters, lifecycle honesty, perf pass

## User-reported issues fixed

1. **Logs section removed from Settings** — card + import gone
   (`lib/ui/settings/settings_screen.dart`). `LogsScreen` file + its test kept
   (dead route, deletable later).
2. **Pill not centered** — pill window inherited the bubble's edge X.
   `resizeOverlay` now takes `centerX`: native centers the window for the pill
   stretch, saves the bubble's X (`savedRestX`) and restores it on the shrink
   back. Files: `OverlayService.java` (method channel + resizeOverlay),
   `overlay_window.dart` (param), `overlay_entry.dart` (centerX: true on pill).
3. **Fox ears clipped in bubble** — `assets/branding/foxyco_bubble.png`
   regenerated from `references/logo/ChatGPT Image Jul 14, 2026, 08_37_19 AM.png`
   (1024 RGBA): alpha-threshold crop → square pad → composited over solid navy
   (#0D1321) disc → 512px. Full head incl. ears now visible.
4. **Top-offers filter showed nothing** — `_passes` required
   `verdict == good AND payout >= minFare`; OK/BAD offers over the floor
   vanished. Now a pure fare floor. (`history_screen.dart`)
5. **History verdict grouping** — new `_VerdictChips` (All/Good/OK/Bad,
   multi-select, same semantics as app chips via shared `_toggleIn`).
6. **Large pill preview overflow stripes** — preview wrapped in
   `FittedBox(scaleDown)` (`settings_screen.dart`).
7. **Pill→bubble retract janky** — `_clearPill` now lets the AnimatedSwitcher
   cross-fade play inside the still-large window, THEN shrinks (Motion.base +
   40ms timer; skipped if a new offer landed). (`overlay_entry.dart`)
8. **Pill legend for new users** — `_PillLegend` under the preview: verdict
   block color, green km = pickup within radius, red km = beyond, $/hr.
9. **Stale "online" after swipe-away** — two-sided fix:
   - `OverlayService.onTaskRemoved` → sendActionToApp("stopWatching") + stopSelf.
   - `refreshPermissions`: `watching` only survives if `overlayService.isActive()`;
     `paused` exempt (its overlay is down by design — resilience test guards this).

## Performance pass

- `FOXYCO_WALK` diagnostics gated behind `DEBUG_WALK = false`
  (AccessibilityListener.java) — was full node scan + per-window getRoot() IPC
  + string builds on EVERY a11y event.
- Gson instance hoisted to static final (was new per event).
- Overlay isolate: per-frame `debugPrint` in build() removed (fired every
  animation frame); `_onData` print gated with kDebugMode.
- Per-read foxLog line in `offer_watcher._onRead` moved inside kDebugMode —
  release builds no longer string-build + disk-flush per a11y event.
- Leak check: nodeMap is LruCache(512) — bounded, OK for long sessions.
- **Self-restart: NOT added.** With logging gated + bounded cache there's no
  known accumulation; add only if a real long-shift degradation shows up.

## Validation

- `flutter analyze` clean; 162/162 tests pass.
- `flutter build apk --debug` OK (Java patches compile).
- Manual rows M8.1–M8.11 in docs/MANUAL_TESTS.md — all pending device run.

## Loose ends

- Hero card redesign still awaiting pick (references/foxyco_hero_options.html).
- `LogsScreen` + `logs_screen_test.dart` now unreachable from UI — delete when
  confident logs are never needed again (foxLog file still written in debug).
- All uncommitted on m6-showroom with earlier M6/M7 work.
