# Settings Redesign + Money Font Picker + Vehicle Silhouettes — Design

Date: 2026-07-21
Branch: m6-showroom (or follow-up feature branch)

## Problem

1. Fraunces serif on money values ($ amounts) looks good but reads poorly.
2. Garage vehicle art (icon-on-chip `VehicleBadge`) looks bad — second rejected attempt after painted `VehicleArt`.
3. Settings page is one long flat scroll; car reminders grow unbounded and push later groups far down.

## Decisions (user-confirmed)

- Money fonts: **Fraunces + Inter + Space Grotesk**, picker with live `$24.50` sample per font. Default: **Inter** (new installs AND existing users; Fraunces available via picker).
- Vehicle art: **curated vector silhouettes** (CustomPainter side profiles per body type).
- Settings layout: **accordion card tiles, one open at a time**.
- Reminders: **show 3 soonest + "Show all (N)" inline toggle** inside Garage group.

## 1. Money font picker

- Add `SpaceGrotesk.ttf` (OFL) to `fonts/`, register in pubspec as family `Space Grotesk`. Include OFL license txt beside it.
- `MoneyFont` enum `{fraunces, inter, spaceGrotesk}` with `label` and `family` getters; lives in domain (near `FoxSettings`).
- `FoxSettings` gains `moneyFont` field, persisted via existing settings persistence; default `MoneyFont.inter`.
- `AppTheme.dark` becomes `AppTheme.dark(MoneyFont font)` (or param with default) — `FoxFonts.display` usages in `_textTheme` (`displayLarge`, `headlineMedium`, `titleLarge`) switch to `font.family`. `main.dart` watches `settingsProvider.select((s) => s.moneyFont)` and passes into theme so all display/money text app-wide follows: home hero, shift recap, history, offer detail, splash, verdict pill.
- Picker UI: new **Appearance** group in settings. Three selectable cards side by side (or stacked), each renders `$24.50` at ~28sp in its font + font name below. Selected card: orange (`brandFox`) border + soft glow. Tap = save instantly, theme rebuilds live.

## 2. Vehicle silhouettes

- New widget `VehicleSilhouette` replacing chip-icon rendering inside `vehicle_badge.dart` (keep file + `VehicleBadge` name so call sites in settings_screen + vehicle_editor_screen unchanged).
- CustomPainter: hand-tuned side-profile `Path` per `VehicleType` (sedan, suv, hatchback, pickup, van, motorbike). Single closed body path + wheel circles (cutout or darker fill).
- Styling matches showroom theme: body fill = vertical gradient of vehicle color (lighter top, darker bottom), thin cream rim-light stroke along roof line, soft elliptical ground shadow beneath.
- EV/hybrid mini-badge (bolt/recycling in circle) preserved as overlay, unchanged.
- Wide aspect (~2:1) instead of square chip; garage list rows and editor adapt spacing only.

## 3. Accordion settings groups

- Groups (order): Driver, Garage (vehicles + car reminders), Verdict thresholds, Live preview, Pickup guard, Watched apps, Pill size, Appearance (new), History.
- Each group = card tile. Collapsed header row: section icon + title + one-line live summary + chevron. Summaries e.g.:
  - Driver: driver name
  - Garage: "2 vehicles · 3 reminders"
  - Verdict thresholds: "GOOD ≥ $1.40/km" (respects rate mode)
  - Live preview: "Try a sample rate"
  - Pickup guard: current state/distance
  - Watched apps: "N apps"
  - Pill size: current size label
  - Appearance: current font name
  - History: retention label
- Behavior: tap header toggles; opening a tile collapses the currently open one (single-open accordion). `AnimatedSize`/`AnimatedCrossFade` for expand animation. First group (Driver) open by default. Open-state is ephemeral (not persisted).
- Expanded body reuses existing section internals unchanged (`_Card` contents, sliders, chips, `ReminderSection`, `_GarageList`).
- Existing `_staggered` entrance animation kept on tiles. `_SectionLabel` widget retires in favor of tile headers.

## 4. Reminder containment

- `ReminderSection` list: sort by soonest due; render first 3; if more, inline `TextButton` "Show all (N)" ↔ "Show less". Local widget state only.

## Error handling / migration

- `moneyFont` absent in stored settings → default `MoneyFont.inter` (this is the intended migration for existing users; no explicit migration code beyond enum default).
- Unknown persisted font value → fall back to inter.

## Testing

- `flutter analyze` clean.
- Unit: `FoxSettings` serialization round-trip with `moneyFont`; unknown value fallback.
- Existing garage/reminder tests keep passing.
- Manual (device): font switch reflects on home hero + history immediately; silhouettes per body type look right; accordion single-open behavior; reminders show-3 toggle; add rows to docs/MANUAL_TESTS.md.

## Risks

- Silhouette paths are aesthetic — need device check (two prior art attempts rejected). Simple side profiles + theme lighting chosen deliberately.
- Theme rebuild on font change: whole-app rebuild but only on explicit tap — fine.
- settings_screen.dart is 47.8K; accordion refactor touches its whole layout skeleton but not the control internals.
