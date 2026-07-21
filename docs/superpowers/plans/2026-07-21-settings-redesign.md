# Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Readable money font (picker with 3 fonts), vector vehicle silhouettes, accordion settings groups, contained reminder list.

**Architecture:** `FoxFonts.display` becomes a mutable static set from persisted `FoxSettings.moneyFont`; the theme rebuild in `main.dart` re-renders everything, so the 16 existing `FoxFonts.display` call sites need zero edits. Overlay isolate gets the font via a new `OverlayPayload` field (same pattern as `size`). Settings screen layout skeleton becomes single-open accordion group cards wrapping the existing section internals unchanged.

**Tech Stack:** Flutter, Riverpod (Notifier), SharedPreferences JSON blob, CustomPainter.

## Global Constraints

- Default money font: **Inter** (spec — existing users migrate to Inter via enum default).
- Fonts: Fraunces, Inter, Space Grotesk only. Space Grotesk under OFL, license txt committed beside TTF.
- No new pub dependencies.
- Dark showroom design language: `FoxColors`/`Gap`/`Radii`/`Shadows`/`Motion` tokens only, no raw colors except inside the silhouette painter's gradients derived from vehicle color.
- `flutter analyze` clean after every task.
- Run tests with `flutter test <file>`; whole suite in final task.

---

### Task 1: MoneyFont enum + settings field

**Files:**
- Create: `lib/domain/money_font.dart`
- Modify: `lib/domain/fox_settings.dart`
- Modify: `lib/ui/settings/settings_controller.dart`
- Test: `test/money_font_test.dart`

**Interfaces:**
- Produces: `enum MoneyFont { inter, fraunces, spaceGrotesk }` with `String label`, `String family`, `static MoneyFont fromName(String?)`; `FoxSettings.moneyFont` field (default `MoneyFont.inter`); `SettingsController.setMoneyFont(MoneyFont)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/money_font_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/money_font.dart';

void main() {
  test('defaults to inter', () {
    expect(FoxSettings.defaults.moneyFont, MoneyFont.inter);
  });

  test('round-trips through json', () {
    final s = FoxSettings.defaults.copyWith(moneyFont: MoneyFont.spaceGrotesk);
    final back = FoxSettings.fromJson(s.toJson());
    expect(back.moneyFont, MoneyFont.spaceGrotesk);
  });

  test('old blobs without moneyFont fall back to inter', () {
    final j = FoxSettings.defaults.toJson()..remove('moneyFont');
    expect(FoxSettings.fromJson(j).moneyFont, MoneyFont.inter);
  });

  test('unknown persisted name falls back to inter', () {
    final j = FoxSettings.defaults.toJson()..['moneyFont'] = 'wingdings';
    expect(FoxSettings.fromJson(j).moneyFont, MoneyFont.inter);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/money_font_test.dart`
Expected: FAIL — `money_font.dart` doesn't exist / no `moneyFont` getter.

- [ ] **Step 3: Implement**

```dart
// lib/domain/money_font.dart
/// Typeface for the big money numbers ($ amounts) app-wide. Driver-picked in
/// Settings → Appearance; Inter is the readable default (Fraunces looked good
/// but read poorly — device feedback 2026-07-21).
enum MoneyFont {
  inter('Inter', 'Inter'),
  fraunces('Fraunces', 'Fraunces'),
  spaceGrotesk('Space Grotesk', 'Space Grotesk');

  const MoneyFont(this.label, this.family);

  /// Picker display name.
  final String label;

  /// Registered pubspec font family.
  final String family;

  /// Null-safe persisted-name lookup; unknown → [inter].
  static MoneyFont fromName(String? name) =>
      values.where((f) => f.name == name).firstOrNull ?? MoneyFont.inter;
}
```

In `lib/domain/fox_settings.dart`:
- Add import: `import 'money_font.dart';`
- Add field after `trackOutcomes` (line 39): 
```dart
  /// Typeface for the big money numbers, picked in Settings → Appearance.
  final MoneyFont moneyFont;
```
- Constructor: add `this.moneyFont = MoneyFont.inter,` (optional with default — old call sites compile unchanged).
- `defaults`: add `moneyFont: MoneyFont.inter,`.
- `copyWith`: add param `MoneyFont? moneyFont,` and `moneyFont: moneyFont ?? this.moneyFont,`.
- `toJson`: add `'moneyFont': moneyFont.name,`.
- `fromJson`: add `moneyFont: MoneyFont.fromName(j['moneyFont'] as String?),`.

In `lib/ui/settings/settings_controller.dart`:
- Add import: `import '../../domain/money_font.dart';`
- Add after `setTrackOutcomes` (line 108):
```dart
  void setMoneyFont(MoneyFont font) => _set(state.copyWith(moneyFont: font));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/money_font_test.dart && flutter analyze`
Expected: PASS, analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/money_font.dart lib/domain/fox_settings.dart lib/ui/settings/settings_controller.dart test/money_font_test.dart
git commit -m "feat: MoneyFont enum + persisted moneyFont setting (default Inter)"
```

---

### Task 2: Space Grotesk font asset

**Files:**
- Create: `fonts/SpaceGrotesk.ttf`, `fonts/OFL_SpaceGrotesk.txt`
- Modify: `pubspec.yaml:108-114`

**Interfaces:**
- Produces: pubspec family `Space Grotesk` (must match `MoneyFont.spaceGrotesk.family` from Task 1).

- [ ] **Step 1: Download font + license**

```bash
cd /home/vamsi/github/foxyco
curl -fL -o fonts/SpaceGrotesk.ttf "https://github.com/google/fonts/raw/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf"
curl -fL -o fonts/OFL_SpaceGrotesk.txt "https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt"
ls -la fonts/
```
Expected: `SpaceGrotesk.ttf` present, non-trivial size (~150-400K), OFL txt present. If curl fails (offline), STOP and report — do not stub the file.

- [ ] **Step 2: Register in pubspec**

In `pubspec.yaml`, after the Inter entry (line 112-114):
```yaml
    - family: Space Grotesk
      fonts:
        - asset: fonts/SpaceGrotesk.ttf
```
(Indentation matches existing Fraunces/Inter entries.)

- [ ] **Step 3: Verify**

Run: `flutter pub get && flutter analyze`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add fonts/SpaceGrotesk.ttf fonts/OFL_SpaceGrotesk.txt pubspec.yaml
git commit -m "feat: bundle Space Grotesk (OFL) as third money font"
```

---

### Task 3: Wire font through theme + overlay isolate

**Files:**
- Modify: `lib/ui/theme/tokens.dart:11-15`
- Modify: `lib/main.dart:92-100`
- Modify: `lib/domain/overlay_payload.dart`
- Modify: `lib/ui/overlay/overlay_controller.dart:105-112`
- Modify: `lib/ui/overlay/overlay_entry.dart` (where offer maps are decoded)
- Test: `test/overlay_payload_test.dart` (extend)

**Interfaces:**
- Consumes: `MoneyFont` (Task 1).
- Produces: `FoxFonts.display` is now `static String` (mutable); `OverlayPayload.moneyFont` field serialized as `'moneyFont'` name string.

- [ ] **Step 1: Write the failing test**

Append to `test/overlay_payload_test.dart` (add import `package:foxyco/domain/money_font.dart`):

```dart
  test('moneyFont round-trips through shareData map', () {
    const p = OverlayPayload(
      verdict: Verdict.good,
      totalKm: 5,
      payout: 10,
      moneyFont: MoneyFont.spaceGrotesk,
    );
    expect(OverlayPayload.fromMap(p.toMap()).moneyFont, MoneyFont.spaceGrotesk);
  });

  test('moneyFont missing from map falls back to inter', () {
    const p = OverlayPayload(verdict: Verdict.good, totalKm: 5, payout: 10);
    final m = p.toMap()..remove('moneyFont');
    expect(OverlayPayload.fromMap(m).moneyFont, MoneyFont.inter);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/overlay_payload_test.dart`
Expected: FAIL — no `moneyFont` on OverlayPayload.

- [ ] **Step 3: Implement**

`lib/ui/theme/tokens.dart` — replace the `FoxFonts` class (lines 10-15):

```dart
/// Type families. [display] carries the big money numbers and is driver-picked
/// (Settings → Appearance, [MoneyFont]); main.dart / the overlay isolate set it
/// before each theme build, so per-widget `fontFamily: FoxFonts.display`
/// call sites follow without edits. Inter carries everything else.
class FoxFonts {
  const FoxFonts._();
  static String display = 'Inter';
  static const sans = 'Inter';
}
```

`lib/domain/overlay_payload.dart`:
- Add import: `import 'money_font.dart';`
- Add field after `pickupNearKm` (line 25):
```dart
  /// Typeface for the pill's money numbers (Settings → Appearance). Carried in
  /// the payload because the overlay isolate can't read SharedPreferences from
  /// the main isolate's provider.
  final MoneyFont moneyFont;
```
- Constructor: add `this.moneyFont = MoneyFont.inter,`.
- `toMap`: add `'moneyFont': moneyFont.name,`.
- `fromMap`: add `moneyFont: MoneyFont.fromName(map['moneyFont'] as String?),`.

`lib/ui/overlay/overlay_controller.dart` — in the offer payload construction at line 105-112, add `moneyFont: settings.moneyFont,` (the `settings` local already exists there; verify by reading the surrounding function first). Leave the other `OverlayPayload(` call sites (127-139) on the default.

`lib/main.dart` — replace `build` (lines 92-100):

```dart
  @override
  Widget build(BuildContext context) {
    // Money-font pick lives in settings; poking the static before the theme
    // builds means every `fontFamily: FoxFonts.display` call site follows on
    // the rebuild this watch triggers.
    final moneyFont = ref.watch(
      settingsProvider.select((s) => s.moneyFont),
    );
    FoxFonts.display = moneyFont.family;
    return MaterialApp.router(
      title: 'FoxyCo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
```

Add imports to `main.dart`: `import 'ui/settings/settings_controller.dart';` and `import 'ui/theme/tokens.dart';`.

`lib/ui/overlay/overlay_entry.dart` — find where the incoming `shareData` offer map is decoded via `OverlayPayload.fromMap` (Read the file first; grep `fromMap`). Immediately after decoding, before the pill builds:

```dart
    FoxFonts.display = payload.moneyFont.family;
```

(`tokens.dart` is already imported there.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/overlay_payload_test.dart test/money_font_test.dart && flutter analyze`
Expected: PASS, analyze clean. If analyze flags a `const` constructor invocation of `TextStyle(fontFamily: FoxFonts.display)` anywhere (static is no longer const), drop that one `const` keyword — do NOT revert the mutable static.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/theme/tokens.dart lib/main.dart lib/domain/overlay_payload.dart lib/ui/overlay/overlay_controller.dart lib/ui/overlay/overlay_entry.dart test/overlay_payload_test.dart
git commit -m "feat: money font flows through theme + overlay isolate payload"
```

---

### Task 4: Accordion settings groups

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart:63-520` (build + `_staggered`; add `_SettingsGroup` widget; retire `_SectionLabel`)
- Modify: `lib/ui/settings/reminder_section.dart:21-28` (strip own card decoration — group card owns it now)
- Test: `test/settings_screen_test.dart` (existing must pass; add open/close test)

**Interfaces:**
- Consumes: existing section internals (`_DriverNameCard`, `_GarageList`, `ReminderSection`, `_ThresholdBand`, `_ThresholdSlider`, `_PresetChips`, `_PreviewCard`, `_ChoiceRow`, `_HealthRow`, `_PillLegend`, `_Card`) — all unchanged except as noted.
- Produces: `_SettingsGroup` widget; `_SettingsScreenState._open` (int, -1 = all closed).

- [ ] **Step 1: Read `test/settings_screen_test.dart` fully** — it pumps the screen and asserts on widgets that may now start collapsed. Note which finders it uses.

- [ ] **Step 2: Add `_SettingsGroup` widget** (place after `_Card`, replacing `_SectionLabel` at lines 825-844):

```dart
/// One accordion group card: tappable header (icon chip + title + live
/// summary + chevron) over an AnimatedSize body. Single-open behavior lives
/// in the parent (`_open` index) so the page never grows unbounded.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String summary;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: open ? FoxColors.border : FoxColors.borderSoft,
        ),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: open ? FoxColors.brandFoxSoft : FoxColors.bgSurface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: open ? FoxColors.brandFox : FoxColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: FoxColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.base,
                    curve: Motion.curve,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: FoxColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // AnimatedSize measures the child, so collapse = height 0 without
          // detaching state while open.
          AnimatedSize(
            duration: Motion.morph,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md, 0, Gap.md, Gap.md,
                    ),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Rewrite the build's ListView children as groups**

In `_SettingsScreenState`, add field `int _open = 0;` and helper:

```dart
  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);
```

Replace the ListView children (keep the header Row with title + Reset button, keep `_staggered` wrapping each group, keep the same `ListView` padding). Each old `_SectionLabel + SizedBox + content` block becomes one `_SettingsGroup`. Gap between groups: `SizedBox(height: Gap.sm)` (tighter than the old `Gap.lg` — collapsed rows read as a list).

Group list, in order, with headers and summaries (compute these locals at the top of `build` — `garage`, `reminders` via `ref.watch(garageProvider)` / `ref.watch(reminderProvider)`; add import of `reminder_controller.dart` and use existing garage import):

| i | title | icon | summary expression | body |
|---|-------|------|--------------------|------|
| 0 | Driver | `Icons.person_outline_rounded` | `ref.watch(driverNameProvider)` value or `'Set your name'` | `_DriverNameCard()` |
| 1 | Garage | `Icons.garage_outlined` | `'${garage.vehicles.length} vehicle${garage.vehicles.length == 1 ? '' : 's'} · ${reminders.length} reminder${reminders.length == 1 ? '' : 's'}'` | Column: `_GarageList()`, `SizedBox(height: Gap.lg)`, sub-label Row (`Icons.notifications_none_rounded` 14 textDisabled + `Text('CAR REMINDERS', style: text.labelSmall)`), `SizedBox(height: Gap.sm)`, `ReminderSection()` |
| 2 | Verdict thresholds | `Icons.tune_rounded` | `'GOOD ≥ \$${t.goodAtOrAbove.toStringAsFixed(2)}$unit'` | old threshold card's inner Column (mode blurb, SegmentedButton, presets, band, 2 sliders) — WITHOUT the `_Card` wrapper |
| 3 | Live preview | `Icons.visibility_outlined` | `'Try a sample rate'` | `_PreviewCard(...)` unchanged (its own `_Card` is fine nested — it's a distinct visual) → actually strip: change `_PreviewCard`'s root from `_Card(child: ...)` to plain `Column` since the group card now provides the surface |
| 4 | Pickup guard | `Icons.near_me_outlined` | `'Near ≤ ${settings.pickupNearKm.toStringAsFixed(1)} km'` | old inner Column (slider + caption), no `_Card` |
| 5 | Watched apps | `Icons.apps_rounded` | `settings.watchedApps.map((a) => a.label).join(' · ')` | old Material+Column of SwitchListTiles, no `_Card` |
| 6 | Outcome tracking | `Icons.fact_check_outlined` | `settings.trackOutcomes ? 'On' : 'Off'` | old inner Column, no `_Card` |
| 7 | Pill size | `Icons.circle_outlined` | pill size label (`'Small'`/`'Medium'`/`'Large'` via the same switch) | old Column: `_ChoiceRow` (no `_Card`), pill preview `FittedBox`, `_PillLegend` |
| 8 | Appearance | `Icons.text_fields_rounded` | `settings.moneyFont.label` | placeholder `SizedBox.shrink()` — Task 5 fills it |
| 9 | Parser health | `Icons.monitor_heart_outlined` | `'This session'` | old Column of `_HealthRow`s + caption, no `_Card` |
| 10 | History | `Icons.history_rounded` | `settings.retentionDays == FoxSettings.keepForever ? 'Keep forever' : 'Keep ${settings.retentionDays} days'` | old inner Column (choice row, export/clear buttons), no `_Card` |

Each group widget:

```dart
        _staggered(
          i,
          _SettingsGroup(
            title: '...',
            icon: ...,
            summary: ...,
            open: _open == i,
            onTap: () => _toggle(i),
            child: ...,
          ),
        ),
        const SizedBox(height: Gap.sm),
```

`_staggered` keeps its current body but change the instant-render cutoff from `i > 7` to `i > 10` only if all rows fit above the fold collapsed — they do (11 × ~66dp ≈ 730dp); keep `i > 7` as-is to avoid animating below-fold rows. `_SectionLabel` class: delete (now unused). `_Card` class: KEEP — `_GarageList`'s vehicle cards and Task 5 may not use it, but deleting is only allowed if analyze reports it unused; if unused, delete.

`driverNameProvider` is already imported via `settings_screen.dart`'s existing imports (it's used in `_DriverNameCard`); check the import list and add `import '../home/profile_card.dart';`-style import only if analyze demands it.

- [ ] **Step 4: Strip `ReminderSection`'s own card decoration**

In `lib/ui/settings/reminder_section.dart:21-28`, the root `Container` with `BoxDecoration` double-cards inside the group. Replace:

```dart
    return Container(
      padding: const EdgeInsets.all(Gap.md + Gap.xs),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
```

with:

```dart
    return Column(
```

(and remove the now-dangling closing paren; keep the Column's children untouched).

- [ ] **Step 5: Fix existing settings_screen tests**

Existing tests that tap/find widgets inside collapsed groups now fail. For each failing finder, open its group first:

```dart
Future<void> openGroup(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}
```

Add one new test:

```dart
  testWidgets('accordion opens one group at a time', (tester) async {
    // ...same pump harness as existing tests in this file...
    expect(find.byType(_SettingsGroup), findsNWidgets(11)); // if private type inaccessible, assert via find.text('Garage') etc.
    await tester.tap(find.text('Watched apps'));
    await tester.pumpAndSettle();
    expect(find.text('Uber'), findsOneWidget); // switch tile now visible
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Uber'), findsNothing); // previous group collapsed
  });
```

(Private `_SettingsGroup` isn't importable from tests — use the text-visibility assertions only. Adjust expected labels to what the harness actually shows; verify against the real widget tree, not hope.)

- [ ] **Step 6: Run tests**

Run: `flutter test test/settings_screen_test.dart test/reminder_test.dart && flutter analyze`
Expected: PASS, analyze clean (analyze will flag unused imports/classes — remove them).

- [ ] **Step 7: Commit**

```bash
git add lib/ui/settings/settings_screen.dart lib/ui/settings/reminder_section.dart test/settings_screen_test.dart
git commit -m "feat: settings groups collapse into single-open accordion cards"
```

---

### Task 5: Appearance group — money font picker

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart` (fill Appearance group body; add `_FontChoiceCard` widget)
- Test: `test/settings_screen_test.dart` (add picker test)

**Interfaces:**
- Consumes: `MoneyFont` (Task 1), `SettingsController.setMoneyFont` (Task 1), `_SettingsGroup` (Task 4).

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('font picker shows samples and saves choice', (tester) async {
    // ...same pump harness...
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('\$24.50'), findsNWidgets(3));
    await tester.tap(find.text('Space Grotesk'));
    await tester.pumpAndSettle();
    // summary line reflects the pick
    expect(find.text('Space Grotesk'), findsWidgets);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_screen_test.dart`
Expected: FAIL — Appearance body is a placeholder.

- [ ] **Step 3: Implement**

Add import `import '../../domain/money_font.dart';` to `settings_screen.dart`. Replace the Appearance group's placeholder body with:

```dart
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Typeface for the big money numbers — pill, home and '
                  'history.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.md),
                for (final f in MoneyFont.values) ...[
                  _FontChoiceCard(
                    font: f,
                    selected: settings.moneyFont == f,
                    onTap: () => controller.setMoneyFont(f),
                  ),
                  if (f != MoneyFont.values.last)
                    const SizedBox(height: Gap.sm),
                ],
              ],
            ),
```

Add the widget (after `_SettingsGroup`):

```dart
/// One selectable money-font row: live "$24.50" sample rendered in the font
/// itself — the sample IS the choice, no abstract font names to decode.
class _FontChoiceCard extends StatelessWidget {
  const _FontChoiceCard({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final MoneyFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + Gap.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? FoxColors.brandFoxSoft : FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.field),
          border: Border.all(
            color: selected
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$24.50',
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: FoxColors.cream,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    font.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: FoxColors.brandFox,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
```

(`FontFeature` needs `import 'dart:ui' show FontFeature;` unless already imported via flutter/material — check existing usage at line 966; the file already uses `FontFeature`, so no new import.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/settings_screen_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/settings_screen_test.dart
git commit -m "feat: Appearance group with live \$24.50 money-font picker"
```

---

### Task 6: Vehicle silhouettes

**Files:**
- Modify: `lib/ui/theme/vehicle_badge.dart` (replace chip-icon rendering with CustomPainter silhouettes; keep class name `VehicleBadge` and constructor signature so both call sites compile unchanged)
- Test: `test/garage_controller_test.dart` + `test/vehicle_editor_test.dart` (existing must still pass)

**Interfaces:**
- Consumes: `VehicleType`, `FuelType` (domain), `FoxColors`.
- Produces: same `VehicleBadge` API: `{VehicleType bodyType, Color color, FuelType fuelType = gas, double size = 44}`. Rendered box becomes `size * 1.9` wide × `size` tall.

- [ ] **Step 1: Replace `vehicle_badge.dart` contents**

```dart
import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import 'tokens.dart';

/// Side-profile vector silhouette tinted by the vehicle's color, with a cream
/// rim-light and soft ground shadow to sit in the dark showroom. Third take on
/// garage art: painted VehicleArt (rejected 2026-07-20), icon chip (rejected
/// 2026-07-21) — this one keeps shapes minimal so they read at 44dp.
class VehicleBadge extends StatelessWidget {
  const VehicleBadge({
    super.key,
    required this.bodyType,
    required this.color,
    this.fuelType = FuelType.gas,
    this.size = 44,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(size * 1.9, size),
          painter: _SilhouettePainter(bodyType: bodyType, color: color),
        ),
        if (fuelType != FuelType.gas)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: FoxColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: FoxColors.border),
              ),
              child: Icon(
                fuelType == FuelType.ev
                    ? Icons.bolt_rounded
                    : Icons.recycling_rounded,
                size: size * 0.32,
                color: VerdictColors.good,
              ),
            ),
          ),
      ],
    );
  }
}

/// Body + wheels in normalized 190×100 coordinate space, scaled to the canvas.
/// Body: vertical gradient of the vehicle color (lit roof → shadowed sill),
/// thin cream stroke on the whole outline as the rim light, elliptical ground
/// shadow underneath. Wheels: dark discs with a color-tinted hub ring.
class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter({required this.bodyType, required this.color});

  final VehicleType bodyType;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 190, sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    // Ground shadow first, under everything.
    canvas.drawOval(
      const Rect.fromLTWH(15, 82, 160, 14),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final body = _bodyPath(bodyType);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 190, 90)),
    );
    // Rim light — thin cream stroke reads as showroom lighting on dark.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = FoxColors.cream.withValues(alpha: 0.55),
    );

    // Window band: darkened inset strip in the cabin area per body type.
    final win = _windowPath(bodyType);
    if (win != null) {
      canvas.drawPath(
        win,
        Paint()..color = Colors.black.withValues(alpha: 0.42),
      );
    }

    // Wheels (motorbike positions differ).
    final wheels = bodyType == VehicleType.motorbike
        ? const [Offset(45, 78), Offset(145, 78)]
        : const [Offset(52, 80), Offset(140, 80)];
    final wheelR = bodyType == VehicleType.motorbike ? 16.0 : 13.0;
    for (final c in wheels) {
      canvas.drawCircle(c, wheelR, Paint()..color = const Color(0xFF10100E));
      canvas.drawCircle(
        c,
        wheelR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = FoxColors.cream.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        c,
        wheelR * 0.42,
        Paint()..color = Color.lerp(color, Colors.white, 0.25)!,
      );
    }

    canvas.restore();
  }

  /// Closed side-profile outline, nose pointing right, in 190×100 space.
  /// Baseline (sill) sits at y≈74 so wheels at y≈80 half-overlap it.
  static Path _bodyPath(VehicleType t) {
    final p = Path();
    switch (t) {
      case VehicleType.sedan:
        p.moveTo(12, 68);
        p.cubicTo(12, 58, 20, 52, 38, 50); // trunk
        p.cubicTo(52, 34, 66, 28, 92, 28); // rear glass → roof
        p.cubicTo(112, 28, 124, 34, 136, 48); // windshield
        p.cubicTo(160, 50, 176, 56, 178, 66); // hood → nose
        p.cubicTo(179, 72, 176, 74, 170, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 72, 12, 68);
      case VehicleType.suv:
        p.moveTo(12, 66);
        p.cubicTo(12, 50, 16, 42, 30, 40); // tall tail
        p.cubicTo(36, 26, 48, 22, 96, 22); // boxy roof
        p.cubicTo(122, 22, 132, 27, 142, 40);
        p.cubicTo(162, 43, 176, 52, 178, 64);
        p.cubicTo(179, 71, 176, 74, 170, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 72, 12, 66);
      case VehicleType.hatchback:
        p.moveTo(14, 66);
        p.cubicTo(14, 46, 22, 34, 44, 30); // steep hatch
        p.cubicTo(70, 26, 96, 26, 112, 30);
        p.cubicTo(128, 34, 136, 42, 144, 50);
        p.cubicTo(162, 52, 174, 58, 176, 66);
        p.cubicTo(177, 72, 174, 74, 168, 74);
        p.lineTo(22, 74);
        p.cubicTo(16, 74, 14, 72, 14, 66);
      case VehicleType.pickup:
        p.moveTo(12, 64);
        p.lineTo(12, 46); // bed wall
        p.lineTo(84, 46); // bed rail
        p.lineTo(88, 26); // cab rear
        p.cubicTo(104, 22, 120, 24, 130, 40); // cab + windshield
        p.cubicTo(156, 42, 174, 52, 177, 63);
        p.cubicTo(178, 71, 175, 74, 169, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 71, 12, 64);
      case VehicleType.van:
        p.moveTo(12, 64);
        p.cubicTo(12, 34, 14, 24, 28, 22); // tall flat tail
        p.lineTo(118, 22); // long roof
        p.cubicTo(140, 22, 152, 32, 162, 48); // raked front
        p.cubicTo(172, 52, 177, 58, 178, 65);
        p.cubicTo(178, 71, 175, 74, 169, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 71, 12, 64);
      case VehicleType.motorbike:
        // Frame + tank + seat as one lowrider sweep; wheels dominate.
        p.moveTo(28, 66);
        p.cubicTo(34, 54, 48, 50, 62, 52); // tail + seat
        p.cubicTo(80, 42, 100, 40, 116, 46); // tank
        p.cubicTo(130, 40, 142, 44, 152, 56); // bars → front fork top
        p.cubicTo(156, 62, 152, 68, 144, 68);
        p.cubicTo(120, 74, 70, 74, 40, 72);
        p.cubicTo(32, 72, 26, 70, 28, 66);
    }
    p.close();
    return p;
  }

  /// Cabin glass band; null for the motorbike.
  static Path? _windowPath(VehicleType t) {
    final p = Path();
    switch (t) {
      case VehicleType.sedan:
        p.moveTo(56, 38);
        p.cubicTo(66, 33, 80, 32, 92, 32);
        p.lineTo(118, 32);
        p.cubicTo(126, 36, 130, 42, 132, 47);
        p.lineTo(94, 47);
        p.lineTo(90, 38);
        p.lineTo(56, 47);
        p.close();
        // Two panes: simpler as one band with a pillar gap — draw band only.
        return Path()
          ..moveTo(54, 46)
          ..cubicTo(62, 34, 76, 31, 92, 31)
          ..cubicTo(110, 31, 122, 36, 130, 46)
          ..close();
      case VehicleType.suv:
        return Path()
          ..moveTo(38, 40)
          ..cubicTo(42, 28, 52, 26, 96, 26)
          ..cubicTo(118, 26, 128, 30, 136, 40)
          ..close();
      case VehicleType.hatchback:
        return Path()
          ..moveTo(36, 42)
          ..cubicTo(46, 32, 70, 30, 100, 32)
          ..cubicTo(118, 34, 130, 40, 138, 48)
          ..lineTo(36, 48)
          ..close();
      case VehicleType.pickup:
        return Path()
          ..moveTo(92, 42)
          ..lineTo(94, 29)
          ..cubicTo(104, 26, 116, 28, 124, 40)
          ..close();
      case VehicleType.van:
        return Path()
          ..moveTo(96, 40)
          ..lineTo(96, 26)
          ..lineTo(118, 26)
          ..cubicTo(134, 26, 144, 34, 152, 46)
          ..lineTo(96, 46)
          ..close();
      case VehicleType.motorbike:
        return null;
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.bodyType != bodyType || old.color != color;
}
```

Note: `iconFor` static on the old class — grep for external users first (`grep -rn "VehicleBadge.iconFor" lib test`). If used elsewhere, keep the static method verbatim; if not, drop it.

- [ ] **Step 2: Fix sedan `_windowPath` dead code** — the first sedan block above builds an unused `p`; deliver ONLY the `return Path()..` form for sedan (delete the `p.moveTo(56, 38)…p.close();` lines). Analyze must be clean.

- [ ] **Step 3: Layout check at call sites** — `_VehicleCard` (settings_screen.dart:1302) and vehicle editor preview. Badge is now 1.9× wider (83.6×44 at default). Read both call sites; if the editor uses a larger `size`, confirm the row still fits (wrap in `FittedBox(fit: BoxFit.scaleDown)` ONLY if it overflows in tests).

- [ ] **Step 4: Run tests**

Run: `flutter test test/garage_controller_test.dart test/vehicle_editor_test.dart test/settings_screen_test.dart && flutter analyze`
Expected: PASS, clean. Overflow errors in test logs = apply the FittedBox fix from Step 3.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/theme/vehicle_badge.dart lib/ui/settings/settings_screen.dart
git commit -m "feat: vector side-profile vehicle silhouettes replace icon chips"
```

---

### Task 7: Reminder list containment (show 3 + expand)

**Files:**
- Modify: `lib/ui/settings/reminder_section.dart:13-72`
- Test: `test/reminder_test.dart` (extend)

**Interfaces:**
- Consumes: `reminderProvider` (already soonest-first sorted by `ReminderController._sorted`).
- Produces: none new.

- [ ] **Step 1: Write the failing test**

Append to `test/reminder_test.dart` (reuse its existing pump harness for `ReminderSection`; Read the file first to match):

```dart
  testWidgets('shows 3 soonest, expands to all', (tester) async {
    // seed 5 reminders via the controller in the harness's ProviderScope
    // (titles R1..R5, dates today+1..today+5)
    // ...pump ReminderSection...
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('R3'), findsOneWidget);
    expect(find.text('R4'), findsNothing);
    await tester.tap(find.text('Show all (5)'));
    await tester.pumpAndSettle();
    expect(find.text('R5'), findsOneWidget);
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('R4'), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reminder_test.dart`
Expected: FAIL — all 5 rows render.

- [ ] **Step 3: Implement**

Convert `ReminderSection` to `ConsumerStatefulWidget` with `bool _showAll = false;`. In build:

```dart
    final reminders = ref.watch(reminderProvider);
    const cap = 3;
    final visible = _showAll ? reminders : reminders.take(cap).toList();
```

Render `visible` in the existing row loop (divider check against `visible.last`). After the rows, before the add button:

```dart
          if (reminders.length > cap)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              style: TextButton.styleFrom(
                foregroundColor: FoxColors.textSecondary,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                _showAll ? 'Show less' : 'Show all (${reminders.length})',
              ),
            ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/reminder_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/reminder_section.dart test/reminder_test.dart
git commit -m "feat: reminder list caps at 3 with show-all toggle"
```

---

### Task 8: Full verification + manual test rows

**Files:**
- Modify: `docs/MANUAL_TESTS.md` (append rows)

- [ ] **Step 1: Full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass. Fix regressions before proceeding.

- [ ] **Step 2: Debug build compiles**

Run: `flutter build apk --debug`
Expected: builds. (Device install/verify is the user's manual step — install user 0 only.)

- [ ] **Step 3: Append manual test rows to `docs/MANUAL_TESTS.md`** (Read the file first, match its exact table format):

- Settings: 11 collapsed group cards, Driver open by default; opening one collapses the other; chevron rotates.
- Appearance: 3 font cards each render "$24.50" in their own face; tapping switches home hero + history amounts instantly; survives app restart.
- Overlay pill: after switching font, next offer's $ figures use the picked font (payload round-trip).
- Garage: silhouettes per body type (sedan/SUV/hatch/pickup/van/bike) look right at row size, color tint + EV badge intact.
- Reminders: 5+ reminders show 3 + "Show all (5)"; expand/collapse works; group summary count correct.

- [ ] **Step 4: Commit**

```bash
git add docs/MANUAL_TESTS.md
git commit -m "docs: manual test rows for settings redesign"
```
