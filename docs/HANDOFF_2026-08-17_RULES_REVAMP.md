# FoxyCo handoff — Rules revamp and Aug 16 media fixes

**Date:** 2026-08-17  
**Workspace:** `/home/vamsi/github/foxyco`  
**Branch:** `main`  
**Source version:** `1.0.9+39`

## Current session status

The current Rules polish is in the worktree and needs the next session's
Flutter/build verification. The Verdict Thresholds expanded layout was kept at
its tuned size.

## Release checkpoint

The requested release preflight passed after updating the two stale settings
test expectations:

- Flutter analysis passed.
- Complete Flutter test suite passed.
- Firestore rules tests passed.
- `./scripts/build.sh aab --bump` advanced `1.0.9+35` to `1.0.9+36`.
- AAB: `dist/FoxyCo-v1.0.9+36-release-20260817-0013.aab`.

The only build message was the existing harmless CupertinoIcons/MaterialIcons
font-tree-shaking notice.

## Aug 16 media findings and fixes

Evidence reviewed from `C:\Users\vamsi\Downloads\fox\Aug 16`:

- Uber offer cards could linger after dismissal. A browse-page Uber earnings
  chip such as `$17.30` was being mistaken for an offer card; browse parsing
  now requires offer-card structure before creating/updating a pill.
- The grey rectangle around the Foxy bubble was a native overlay SurfaceView
  transparency race. `OverlayService.java` now keeps the Flutter surface
  transparent and reapplies transparent format/Z ordering after layout changes.
- Shift recap now includes the count of accepted offers for the session.
- The unlocked-app settings group was moved into Profile.
- Voice announcements now use independent GOOD and OK payout cutoffs. GOOD
  voice additionally requires both the configured $/km and $/hr GOOD rules;
  OK voice requires an OK verdict and its own payout cutoff.
- Voice cutoffs persist through `FoxSettings` JSON and are clamped to CA$0–500.
- Existing watcher, parser, decision-engine, and settings regression tests were
  extended for these behaviors.

## Rules page revamp

### Verdict thresholds

The page now explains the previously implicit middle band:

```text
BAD       < bad threshold
OK        bad threshold ≤ rate < good threshold
GOOD      ≥ good threshold
```

The threshold summary and explanatory copy show the OK range directly. GOOD
and BAD controls retain their right-side static values and −/+ precision
buttons. The collapsed OK summary uses readable amber/gold; GOOD is green and
BAD is red. Relaxed/Balanced/Picky remain functional in both modes, with hourly
presets at 18/26, 20/30, and 24/36 (BAD/GOOD).

### Live preview

The old sample-rate slider/preset UI was replaced with a real production
`VerdictPill` preview. Users edit three inputs:

- Offer payout
- Distance
- Time

The preview calculates both rates using the same offer math as production:

```text
$/km = payout ÷ distance
$/hr = payout ÷ minutes × 60
```

The selected rate mode alone determines the verdict after the Minimum Offer
hard BAD floor. The active metric and concise reason are primary; the inactive
rate is neutral secondary information. Pickup status is separate and can be
green/red without changing GOOD/OK/BAD.

Minimum Offer remains: below the enabled minimum is BAD immediately; equal or
above continues selected-mode scoring; OFF leaves the value visible but dimmed
and bypasses the check.

### Road sliders

All Rules sliders use the supplied right-facing orange asset:

`assets/car/foxy_road_car.png`

The asset is transparent, remains orange in every state, and is declared by
the existing `assets/car/` pubspec wildcard. `RoadSlider` draws the road,
active semantic color, dashed lane marks, car position, and a small Flutter-
painted headlight gradient. The glow appears while dragging or while the car
animates to a changed preset value, then fades in roughly 160 ms.

There is no floating value tooltip, bubble, popup, or second value. The static
right-side value and existing −/+ controls remain the precision interaction.

Semantic road colors are:

- GOOD: theme-aware verdict green.
- OK: theme-aware amber/gold.
- BAD: theme-aware verdict red.
- Minimum offer amount: FoxyCo orange.
- Other controls retain their existing contextual colors.

Pickup copy is `Highlight pickup distance in the offer pill.` Preview status is
green `At or under …` or red `Over …`; pickup distance is informational only.

Slider value indicators are explicitly disabled. The old Material font car
thumb was removed.

## Important files changed

- `lib/ui/rules/rules_screen.dart` — threshold explanation, real pill preview,
  payout/distance/time math, and Rules road-slider usage.
- `lib/ui/settings/settings_controls.dart` — `RoadSlider`, road painter,
  headlight painter, transparent slider interaction, and no tooltip.
- `assets/car/foxy_road_car.png` — supplied orange transparent car asset.
- `lib/domain/fox_settings.dart` — persisted voice payout cutoffs.
- `lib/domain/decision_engine.dart` — strict voice qualification logic.
- `lib/services/accessibility/offer_watcher.dart` — voice gating and browse
  offer-card lifecycle.
- `lib/parser/offer_parser.dart` — browse-card false-positive guard.
- `lib/ui/home/shift_recap_sheet.dart` — accepted-offer session count.
- `lib/ui/settings/profile_section.dart` and `settings_screen.dart` — Unlock
  moved under Profile.
- `third_party/flutter_overlay_window/android/.../OverlayService.java` —
  transparent SurfaceView restoration.
- `test/settings_screen_test.dart` — assertions for the real pill, hourly
  presets, and pickup status.

## Next-session validation

1. Run `./scripts/build.sh aab --bump`; analysis, Flutter tests, Firestore
   tests, and the AAB build must pass before device install.
2. Inspect Rules in both light and dark themes. Confirm the orange car remains
   right-facing, the road colors are correct, and the headlight glow is subtle
   and temporary.
3. Drag GOOD, BAD, minimum, pickup, voice, and cooldown controls; verify the
   right-side values and −/+ controls remain readable and exact.
4. Edit payout, distance, and time in Live preview; verify the production pill
   and both rate calculations update immediately.
5. Confirm the OK explanation matches the configured BAD/GOOD thresholds in
   both $/km and $/hr modes, and the inactive metric stays neutral.
6. Enable Minimum Offer and test below-minimum, equal-minimum, and OFF cases.
7. Re-test the Aug 16 Uber flow: stale browse earnings chips must not create a
   pill, and a dismissed offer must clear promptly.
8. Re-check the bubble on Samsung/Android after window resize or app switching
   for any return of the grey rectangular mask.

## Known non-blocking build note

The release build prints a CupertinoIcons/MaterialIcons font message while
tree-shaking MaterialIcons. The AAB still completes successfully and the app
uses `uses-material-design: true`.
