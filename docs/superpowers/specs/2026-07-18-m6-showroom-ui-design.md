# M6 — "Showroom": premium dark UI overhaul, garage, slide-to-start, splash

**Date**: 2026-07-18
**Status**: Approved (design conversation 2026-07-18)
**References**: `references/car  profile.png` (car rental cards), `references/start.png` (slide-to-buy), dribbble car-loader GIFs (linked in conversation)

## Goal

The app must read as a sellable, premium product. Every screen moves from
flat-light-static to dark-layered-animated, matching the reference shots'
quality bar, without touching parsing, overlay, or watch-service logic and
without adding packages.

Also fixes one real bug: History header count vs. filtered list mismatch.

## Non-goals

- No changes to overlay bubble/pill runtime (perf-critical, just fixed in M5).
- No changes to parsers, decision engine, or watch service semantics.
- No new dependencies (no Lottie/Rive). Pure Flutter animation only.
- No light-theme toggle. Dark is the only theme after M6.

---

## 1. Dark premium theme (foundation)

Rewrite `lib/ui/theme/tokens.dart` palette in place — same token names where
possible so most call-sites survive untouched.

- **Base background**: deep green-black family anchored on the existing ink
  (`FoxColors.ink` ≈ `#141A17`) — background goes darker (`~#0C1210`), cards
  sit lighter on top. Brand continuity: the M5 hero cards already used this
  ink, now the whole app lives there.
- **Surfaces**: two elevation steps. `bgSurface` = charcoal card with subtle
  top-left→bottom-right gradient + 1px low-alpha light border. `bgSurface2` =
  slightly lighter for nested elements (chips, wells).
- **Accent**: existing FoxyCo orange (`brandFox`) unchanged, gains a glow
  treatment: `Shadows.glow` = soft orange boxShadow used behind active/live
  elements.
- **Text**: cream primary, alpha-stepped secondary/disabled (existing cream
  token becomes the primary text color).
- **Verdict colors**: good/ok/bad hues kept, lightness tuned for dark
  contrast (WCAG AA against card surface).
- ThemeData: dark `ColorScheme`, dark system nav/status bars,
  `scaffoldBackgroundColor` from tokens.

Everything else inherits. Screens may only reference tokens — no inline
`Color(0x...)` in screen files except where a token genuinely doesn't fit.

## 2. Animated launch splash

New `lib/ui/splash/splash_screen.dart`, first route before shell.

- Dark scene. FoxyCo wordmark (existing display serif) fades in.
- Car silhouette (the new premium art, sedan default or active vehicle's
  body type) drives in from left with a headlight beam sweep; a road line
  shimmers underneath.
- Total ~1.8 s, then crossfade to shell. Never blocks: shell providers warm
  up behind it.
- Reduced motion (`MediaQuery.disableAnimations`): static logo, 0.5 s, no
  car, no sweep.
- Implementation: single `AnimationController`, staged `Interval` curves,
  CustomPaint for car/beam/road. No timers besides the controller.
- Splash shows once per cold start only (not on resume).

## 3. Home screen

### 3.1 Hero profile card (rebuild)

- Full-width premium car card in the rental-reference style: large 3/4-view
  car illustration (see §7 Car art), tinted to profile color, over a dark
  gradient stage with a soft ground shadow / floor reflection.
- Greeting bands change (bug-adjacent fix — old code was time-aware but
  bands were wrong for night drivers):
  - 05–11: "Good morning"
  - 12–16: "Good afternoon"
  - 17–21: "Good evening"
  - 22–04: "Late shift" (e.g. "Late shift, Vamsi")
- Vehicle line: `Color Year Make Model · PLATE` plus fuel badge (⚡ for EV,
  leaf-style dot for hybrid, none for gas).
- Card hidden until name set (unchanged M5 rule). Entrance fade+slide and
  sheen loop retained but retuned to new motion spec (§8).

### 3.2 Slide-to-go-live (replaces Go Live button)

- Track: pill, dark well with 1px border. Thumb: orange circle with bolt
  icon, orange glow shadow.
- Drag right: track fills orange behind the thumb with rising glow; label
  "Slide to go live" fades out as fill passes it.
- Commit at ≥85% travel: medium haptic, thumb snaps to end, control morphs
  (~300 ms) into the **Live bar**: slim bar, pulsing live dot, elapsed
  session feel, and the same affordance reversed — slide-to-stop (drag back)
  so stopping is also deliberate.
- Released early (<85%): spring back (overshoot curve), light haptic.
- Wires to the exact same start/stop calls the M5 button used
  (`WatchStatus.stopped` semantics unchanged; pause still lives on bubble
  long-press).
- Reduced motion: no glow pulse; slider still functional (drag is a gesture,
  not an animation) with instant state swap instead of morph.
- A11y: the control is also activatable as a semantic button
  ("Go live" / "Stop") for screen readers — slide is the visual affordance,
  not the only path.

### 3.3 Status card (second hero) rebuild

- App chips (Uber/Hopp/Lyft): platform monogram badge (colored dot →
  lettered roundel), active state clearer.
- "Offers seen today" number: count-up animation on change.
- Seg-bar: always visible. Zero state shows faint track. Non-zero: segments
  animate width with easeOutCubic. Height bumped so it reads as a real
  element, not a hairline.
- good/ok/bad: compact stat chips (dot + count + label in a small well) in a
  row, replacing floating text.

### 3.4 Last offer card

- Dark card, verdict accent as a left edge glow strip (not a plain bar).
- Numeric columns top-aligned on a shared baseline, tabular figures,
  consistent label case.

## 4. Garage (profile system rework)

### 4.1 Data

- New `lib/domain/garage.dart`: `Vehicle` (id, make, model, year, plate,
  colorValue, bodyType, fuelType) + `Garage` (vehicles list, activeId).
  `FuelType { gas, hybrid, ev }`. `VehicleType` enum reused.
- Driver name stays a separate scalar (it's the person, not the car).
- Persistence: `foxyco.garage.v1` JSON blob in SharedPreferences, same
  fail-soft pattern as `OfferLog`.
- **Migration**: on first load, if `foxyco.profile.v1` exists and
  `garage.v1` doesn't, convert the single profile into a one-vehicle garage
  (fuel defaults to gas), mark active, keep old key (harmless) — one-way,
  idempotent.
- `profileProvider` call-sites migrate to a new `garageProvider` +
  `activeVehicleProvider`; hero card and vehicle art read the active
  vehicle.

### 4.2 Settings → Garage UI

- Driver name: own small card at top of the section, explicit save (check
  button appears on edit — no silent live-apply).
- Below: vehicle list as premium mini car-cards — car art thumbnail, `Year
  Make Model`, plate chip, fuel badge, active checkmark. Tap = set active
  (instant, persisted). Long-press or edit icon = open editor.
- "+ Add vehicle" card at the end.

### 4.3 Vehicle editor (full screen)

- New route. Fields: Make, Model, Year, Plate; color swatch row; body type
  chips; **fuel type chips (Gas / Hybrid / EV)**.
- Live preview at top: car art re-tints/re-shapes as the driver edits.
- Explicit **Save** (validates: make or model non-empty) and **Cancel**
  (discards). **Delete** button on existing vehicles with confirm dialog;
  deleting the active vehicle activates the next one; deleting the last one
  leaves an empty garage (hero card hides).
- Nothing persists until Save. This kills the M5 live-apply complaint.

## 5. History

### 5.1 Count bug (the "22 offers, empty list" report)

Root cause: header shows `all.length` (all-time) while the list shows the
filtered range (default Today). Post-midnight, yesterday's offers vanish
from Today but the header still says 22.

- Header count now shows **filtered** count and names the range:
  "0 today", "22 all time", etc.
- Empty state becomes smart: when filters hide existing offers, say
  "22 offers outside these filters" with a one-tap "Show all" that resets
  range to All.

### 5.2 Visual rebuild

- Offer rows: dark cards, verdict left-edge glow strip, platform monogram
  badge, payout/time column right-aligned on tabular figures, km + $/km
  baseline-aligned with platform name.
- Stats card: dark, count-up numbers, equal-width stat columns.
- Rows stagger-fade (≤12 rows animated; rest appear instantly) on filter
  change. Reduced motion: no stagger.
- Range control / chips / top-offers card restyled to dark tokens
  (structure unchanged).

## 6. Settings

- Every section becomes a dark card with a small section icon (person for
  profile/garage, sliders for thresholds, pill for pill size, doc for logs).
- Sections stagger-slide up on screen entry (again ≤ 8 animated).
- Switches, chips, steppers adopt the global motion spec (spring on
  user-driven toggles).
- Verdict threshold cards narrowed: tighter padding, smaller number
  displays, aligned units — fixes "too broad" complaint.
- Live pill-size preview keeps working, restyled dark.

## 7. Car art (the quality bar)

Replace flat `VehiclePainter` silhouettes with layered premium CustomPaint
art, one paint program per body type (sedan, suv, hatchback, pickup, van,
motorbike), used at three sites: hero card (large), garage cards (thumb),
splash (silhouette pass).

Each render layers:
1. Ground shadow ellipse (soft blur).
2. Body base fill in profile color with vertical light-to-dark gradient.
3. Roofline/hood highlight sweep (low-alpha white gradient).
4. Glass: dark blue-grey with a diagonal reflection streak.
5. Wheel wells + wheels: tire ring, rim with spoke hints, hub dot.
6. Detail pass: door seam line, handle tick, head/tail light glints
   (headlight warm, taillight red).
7. EV fuel type adds a small bolt badge near the rear wheel; hybrid a small
   two-tone dot; gas nothing.

3/4-view proportions (not flat side-view) to match the reference cards'
depth. All coordinates fractional; art scales hero→thumb.

**Fallback**: if device check says still not premium enough, next milestone
sources licensed PNG art per body type — the painter sits behind one
`VehicleArt` widget so the swap is contained.

## 8. Motion language (global spec)

- Durations: 200–300 ms standard; splash is the only longer sequence.
- Curve: easeOutCubic for state changes; overshoot/spring
  (`Curves.easeOutBack` or spring sim) only for user-driven gestures
  (slider release, toggle).
- Numbers: count-up via `TweenAnimationBuilder<int>` on change.
- Lists: stagger 30–40 ms/item, capped as per screen sections above.
- Reduced motion: every animation site checks
  `MediaQuery.disableAnimations` — result is instant swaps, zero loops.
- No animation may run while the watch service is parsing in foreground
  service context — all of this is in-app UI only, overlay untouched.

## 9. Architecture / files

- `lib/ui/theme/tokens.dart` — rewritten palette + `Shadows.glow` + motion
  constants.
- `lib/ui/splash/splash_screen.dart` — new.
- `lib/ui/home/home_screen.dart` — status card, last offer, slide control.
- `lib/ui/home/slide_to_live.dart` — new widget.
- `lib/ui/home/profile_card.dart` — hero rebuild, greeting bands.
- `lib/ui/theme/vehicle_art.dart` — new layered painters (moves art out of
  profile_card).
- `lib/domain/garage.dart`, `lib/ui/settings/garage_controller.dart` — new
  model + persistence + migration.
- `lib/ui/settings/settings_screen.dart` — garage section, dark cards,
  stagger.
- `lib/ui/settings/vehicle_editor_screen.dart` — new route.
- `lib/ui/history/history_screen.dart` — count fix + restyle.
- `router.dart` — splash route + editor route.
- Old `profile_controller.dart` shrinks to name-only or folds into garage
  controller (implementation's choice, no duplicate persistence).

## 10. Error handling

- Garage load failure → empty garage, fail-soft, FoxLog line (same pattern
  as OfferLog).
- Migration failure → start with empty garage, never crash, FoxLog line.
- Vehicle editor Save with invalid year/empty fields → inline validation,
  Save disabled or field error; never writes bad data.
- Splash must never trap the user: hard 3 s ceiling, then force-navigate.

## 11. Testing

- `flutter analyze` clean; all existing tests pass (some will need dark-token
  updates).
- New unit tests: garage model round-trip, migration from profile.v1,
  active-vehicle selection, delete-active fallback, greeting bands (05/12/17/
  22 boundaries), history filtered-count logic.
- New widget tests: slide-to-live (commit ≥85%, spring-back <85%, semantic
  button path), vehicle editor save/cancel/delete, history smart empty
  state.
- Manual (device): splash timing, slider feel + haptics, garage flow
  end-to-end, dark contrast in sunlight, OV.1/OV.6 regression (overlay
  untouched but verify), M6 rows added to `docs/MANUAL_TESTS.md`.

## 12. Milestones inside M6 (implementation order)

1. Tokens + theme flip (everything inherits; screens fixed as they break).
2. Garage domain + migration + controllers (logic before pixels).
3. Car art painters.
4. Home (hero, slider, status card, last offer).
5. Garage UI + vehicle editor.
6. History (bug fix + restyle).
7. Settings restyle + stagger.
8. Splash.
9. Test sweep + manual test rows.
