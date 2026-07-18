# M6 "Showroom" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flip FoxyCo to a premium dark theme with garage (multi-vehicle) support, slide-to-go-live control, animated splash, and the History count-bug fix.

**Architecture:** Token-first: rewrite `tokens.dart` dark, everything inherits; then logic (garage domain + migration), then pixels screen by screen. Overlay/parser/watch-service code is never touched. State management stays Riverpod `Notifier` + one-SharedPreferences-JSON-blob persistence (existing pattern).

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), `shared_preferences`, `go_router`. NO new packages.

## Global Constraints

- **No new dependencies.** Pure Flutter animation (no Lottie/Rive).
- **Dark is the only theme after M6.** No light toggle.
- **Never touch:** `lib/ui/overlay/**`, `lib/parser/**`, `lib/services/accessibility/**`, `lib/services/overlay_service.dart`, `lib/domain/decision_engine.dart`, watch-service semantics in `dashboard_controller.dart`.
- Screens reference tokens only — no inline `Color(0x...)` in screen files (exceptions must be justified in a comment).
- Every animation site checks `MediaQuery.of(context).disableAnimations` → instant swap, zero loops.
- Durations 200–300 ms standard (`Motion.*`); `Curves.easeOutCubic` for state changes; overshoot/spring only for user-driven gestures.
- Persistence keys: garage = `foxyco.garage.v1`, driver name = `foxyco.driver.v1`, legacy profile = `foxyco.profile.v1` (read-only, never deleted).
- After each task: `flutter analyze` → 0 issues, `flutter test` → all pass, then commit.
- Commit messages: `feat(m6): <what>` / `fix(m6): <what>` / `test(m6): <what>`.
- Run all commands from repo root `/home/vamsi/github/foxyco`.

---

### Task 1: Dark tokens + theme flip

**Files:**
- Modify: `lib/ui/theme/tokens.dart` (full rewrite of color values, same class/token names + additions)
- Modify: `lib/ui/theme/app_theme.dart` (light → dark scheme)
- Modify: `lib/main.dart` (`AppTheme.light` → `AppTheme.dark`, system bars)
- Modify (mechanical text-color sweep): `lib/ui/home/home_screen.dart`, `lib/ui/history/history_screen.dart`, `lib/ui/settings/settings_screen.dart`, `lib/ui/onboarding/onboarding_screen.dart`, `lib/ui/settings/logs_screen.dart`, `lib/ui/shell/root_shell.dart`

**Interfaces:**
- Produces: new tokens later tasks rely on: `FoxColors.bgSurface2`, `FoxColors.textPrimary` (= cream), `Shadows.glow`, `Shadows.glowSoft`, `Motion.morph` (300ms), `Motion.spring` (`Curves.easeOutBack`), `Motion.stagger` (35ms). All existing token NAMES survive (`bgBase`, `bgSurface`, `border`, `borderSoft`, `ink`, `inkSoft`, `cream`, `creamDim`, `textSecondary`, `textDisabled`, `brandFox*`, `uber/lyft/hopp`, `VerdictColors.*`, `Gap`, `Radii`, `Shadows.card/soft/hero`, `Motion.fast/base/count/curve`).

- [ ] **Step 1: Rewrite `lib/ui/theme/tokens.dart`**

Replace the `VerdictColors`, `FoxColors`, `Shadows`, `Motion` classes with the following (keep `FoxFonts`, `Gap`, `Radii` exactly as they are):

```dart
/// Verdict colors — semantic, fixed. Always paired with a shape + word in UI
/// so they survive colorblindness and glare (never color alone).
///
/// After M6 the whole app is dark, so the bright on-dark tier IS the primary
/// tier; the old names alias it so call-sites survive. [goodBg]/… are
/// translucent tint wells behind labels.
class VerdictColors {
  const VerdictColors._();

  static const good = Color(0xFF4FBB7C);
  static const ok = Color(0xFFEFB94F);
  static const bad = Color(0xFFEA6D62);
  static const unknown = Color(0xFF9A9A8D);

  // Aliases kept so existing call-sites compile unchanged.
  static const goodOnDark = good;
  static const okOnDark = ok;
  static const badOnDark = bad;

  // Translucent tint wells (chips, badges) on dark surfaces.
  static const goodBg = Color(0x264FBB7C);
  static const okBg = Color(0x26EFB94F);
  static const badBg = Color(0x26EA6D62);
}

/// Surface + text colors — deep green-black "showroom" direction (spec M6 §1).
/// Base is darker than the old ink; cards sit lighter on top; cream is now the
/// primary text color everywhere.
class FoxColors {
  const FoxColors._();

  static const bgBase = Color(0xFF0C1210); // deep green-black stage
  static const bgSurface = Color(0xFF161F1A); // cards
  static const bgSurface2 = Color(0xFF1F2A24); // nested chips / wells
  static const border = Color(0x1FF4EFE1); // 12% cream hairline
  static const borderSoft = Color(0x14F4EFE1); // 8% cream

  static const ink = Color(0xFF141A17); // hero-gradient dark stop (kept)
  static const inkSoft = Color(0xFF1C2620); // hero-gradient light stop (kept)
  static const cream = Color(0xFFF4EFE1); // primary text
  static const creamDim = Color(0xC6F4EFE1); // ~0.78 alpha cream

  static const textPrimary = cream;
  static const textSecondary = Color(0x9EF4EFE1); // 62% cream
  static const textDisabled = Color(0x5CF4EFE1); // 36% cream

  /// Foxy orange — accents, logo, primary actions. One accent per screen.
  static const brandFox = Color(0xFFFF5A36);
  static const brandFoxDeep = Color(0xFFB93A1E);
  static const brandFoxSoft = Color(0x33FF5A36); // translucent tint on dark

  // Per-app dot colors. Uber flips light — #111 is invisible on dark.
  static const uber = Color(0xFFEDEDED);
  static const lyft = Color(0xFFFF37A6);
  static const hopp = Color(0xFF4FA3E8);
}
```

```dart
/// Elevation on dark = black depth shadows + the orange glow treatment
/// (spec M6 §1) used behind active/live elements.
class Shadows {
  const Shadows._();

  static List<BoxShadow> get card => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5)),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get hero => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 44, offset: const Offset(0, 26)),
  ];

  /// Orange glow — behind the live slider thumb, live dot, active elements.
  static List<BoxShadow> get glow => [
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.45), blurRadius: 18),
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.20), blurRadius: 40),
  ];

  static List<BoxShadow> get glowSoft => [
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.25), blurRadius: 12),
  ];
}

/// Motion language (spec M6 §8). easeOutCubic for state changes; [spring]
/// ONLY for user-driven gestures (slider release, toggles).
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const morph = Duration(milliseconds: 300);
  static const count = Duration(milliseconds: 400);
  static const stagger = Duration(milliseconds: 35);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}
```

- [ ] **Step 2: Rewrite `lib/ui/theme/app_theme.dart` to a dark scheme**

Replace the whole `AppTheme` class body (keep `_textTheme`, but change its two `color: FoxColors.ink` entries — `displayLarge`, `headlineMedium`, `titleLarge`, `titleMedium`, `bodyMedium` — to `FoxColors.textPrimary`):

```dart
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: FoxColors.bgBase,
      onSurface: FoxColors.textPrimary,
      surfaceContainerHighest: FoxColors.bgSurface,
      primary: FoxColors.brandFox,
      onPrimary: Colors.white,
      outline: FoxColors.border,
      secondary: FoxColors.brandFox,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: FoxFonts.sans,
      scaffoldBackgroundColor: FoxColors.bgBase,
      splashColor: FoxColors.brandFoxSoft,
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: FoxColors.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
          side: BorderSide(color: FoxColors.borderSoft),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FoxColors.bgBase,
        foregroundColor: FoxColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: FoxColors.bgBase,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoxColors.bgSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.brandFox, width: 1.5),
        ),
        labelStyle: const TextStyle(color: FoxColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoxColors.brandFox,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
```

Add import at top of app_theme.dart: `import 'package:flutter/services.dart';` (for `SystemUiOverlayStyle`).

- [ ] **Step 3: Update `lib/main.dart`**

In `_FoxyCoAppState.build`, change `theme: AppTheme.light` → `theme: AppTheme.dark`. In `main()`, after `ensureInitialized()`, add:

```dart
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C1210), // FoxColors.bgBase
    systemNavigationBarIconBrightness: Brightness.light,
  ));
```

with import `import 'package:flutter/services.dart';`.

- [ ] **Step 4: Mechanical text-color sweep**

Find every dark-on-dark text/fill left behind:

```bash
grep -rn "FoxColors.ink" lib/ui --include="*.dart" | grep -v theme/
```

Apply these rules (exact substitutions, screen by screen):
- Any `TextStyle(... color: FoxColors.ink ...)` → `FoxColors.textPrimary`. Known sites: `home_screen.dart` `_TicketStat` value, `_ActiveButton` keeps `(FoxColors.cream, FoxColors.ink, …)` tuple UNCHANGED (light button, dark text — still correct); `history_screen.dart` `_OfferRow` platform label + `$/km` span + payout.
- Selected/active fills that used `FoxColors.ink` as "dark chip on light page": `history_screen.dart` `_RangeControl` indicator `color: FoxColors.ink` → `FoxColors.bgSurface2`; `_AppChips` `_chip` active `color`/`border` `FoxColors.ink` → `FoxColors.bgSurface2` / `FoxColors.border`; `settings_screen.dart` `_ChoiceRow` selected `FoxColors.ink` → `FoxColors.bgSurface2` (both `color:` and `border` color).
- `home_screen.dart` `_AccessAlert`: `border: Border.all(color: const Color(0xFFF0C2BC))` → `Border.all(color: VerdictColors.bad.withValues(alpha: 0.35))`. Wrap its two `TextSpan`s' shared style with `color: FoxColors.textPrimary`.
- `onboarding_screen.dart` + `logs_screen.dart` + `root_shell.dart`: same rule — any `FoxColors.ink` used as a text color → `textPrimary`; used as a dark surface fill → leave (it's still dark, now blends with theme; hero gradients `inkSoft→ink` stay as-is).

- [ ] **Step 5: Analyze, test, eyeball**

```bash
flutter analyze
flutter test
```
Expected: analyze 0 issues. Tests: all pass (existing tests assert text presence/logic, not colors). If a test asserts a color constant, update it to the new token value.

- [ ] **Step 6: Commit**

```bash
git add lib/ui lib/main.dart
git commit -m "feat(m6): flip app to dark showroom theme (tokens + ThemeData + sweep)"
```

---

### Task 2: Garage domain model + unit tests

**Files:**
- Create: `lib/domain/garage.dart`
- Test: `test/garage_test.dart`

**Interfaces:**
- Consumes: `VehicleType` from `lib/domain/driver_profile.dart` (existing enum), `DriverProfile` for migration.
- Produces: `FuelType { gas, hybrid, ev }`; `Vehicle` (`String id, make, model, year, plate; int colorValue; VehicleType bodyType; FuelType fuelType`, `String get vehicleLine`, `String get title`, `copyWith`, `toJson`/`fromJson`); `Garage` (`List<Vehicle> vehicles, String activeId`, `Vehicle? get active`, `Garage upsert(Vehicle)`, `Garage remove(String id)`, `Garage setActive(String id)`, `static const empty`, `toJson`/`fromJson`, `factory Garage.fromLegacyProfile(DriverProfile)`).

- [ ] **Step 1: Write the failing tests** — `test/garage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';

Vehicle _v(String id, {FuelType fuel = FuelType.gas}) => Vehicle(
      id: id,
      make: 'Toyota',
      model: 'Camry',
      year: '2022',
      plate: 'ABC-123',
      colorValue: 0xFFC62828,
      bodyType: VehicleType.sedan,
      fuelType: fuel,
    );

void main() {
  test('json round-trip preserves everything', () {
    final g = Garage(vehicles: [_v('a', fuel: FuelType.ev), _v('b')], activeId: 'b');
    final back = Garage.fromJson(g.toJson());
    expect(back.vehicles.length, 2);
    expect(back.activeId, 'b');
    expect(back.vehicles.first.fuelType, FuelType.ev);
    expect(back.vehicles.first.bodyType, VehicleType.sedan);
    expect(back.active!.id, 'b');
  });

  test('active falls back to first vehicle when activeId is stale', () {
    final g = Garage(vehicles: [_v('a')], activeId: 'gone');
    expect(g.active!.id, 'a');
  });

  test('empty garage has null active', () {
    expect(Garage.empty.active, isNull);
  });

  test('remove active vehicle activates the next one', () {
    final g = Garage(vehicles: [_v('a'), _v('b')], activeId: 'a').remove('a');
    expect(g.vehicles.length, 1);
    expect(g.active!.id, 'b');
    expect(g.activeId, 'b');
  });

  test('remove last vehicle leaves an empty garage', () {
    final g = Garage(vehicles: [_v('a')], activeId: 'a').remove('a');
    expect(g.vehicles, isEmpty);
    expect(g.active, isNull);
  });

  test('upsert replaces by id, appends when new', () {
    var g = Garage(vehicles: [_v('a')], activeId: 'a');
    g = g.upsert(_v('a', fuel: FuelType.hybrid));
    expect(g.vehicles.length, 1);
    expect(g.vehicles.first.fuelType, FuelType.hybrid);
    g = g.upsert(_v('b'));
    expect(g.vehicles.length, 2);
  });

  test('legacy profile with vehicle info migrates to one-vehicle garage', () {
    const p = DriverProfile(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleModel: 'Camry',
      vehicleYear: '2022',
      licensePlate: 'ABC-123',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.sedan,
    );
    final g = Garage.fromLegacyProfile(p);
    expect(g.vehicles.length, 1);
    expect(g.active!.make, 'Toyota');
    expect(g.active!.fuelType, FuelType.gas); // migration default
    expect(g.active!.colorValue, 0xFFC62828);
  });

  test('legacy profile with only a name migrates to an EMPTY garage', () {
    const p = DriverProfile(name: 'Vamsi');
    expect(Garage.fromLegacyProfile(p).vehicles, isEmpty);
  });

  test('vehicleLine formats like the old profile line', () {
    expect(_v('a').vehicleLine, 'Red 2022 Toyota Camry · ABC-123');
  });

  test('fromJson tolerates garbage', () {
    final g = Garage.fromJson({'vehicles': 'nope', 'activeId': 3});
    expect(g.vehicles, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/garage_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package ... garage.dart` / target not found.

- [ ] **Step 3: Implement `lib/domain/garage.dart`**

```dart
import 'driver_profile.dart';

/// Powertrain — drives the fuel badge on cards + art (spec M6 §4.1).
enum FuelType { gas, hybrid, ev }

/// One vehicle in the garage. Pure Dart — color is ARGB int so `domain/`
/// stays Flutter-free; UI wraps it in `Color(...)`.
class Vehicle {
  const Vehicle({
    required this.id,
    this.make = '',
    this.model = '',
    this.year = '',
    this.plate = '',
    this.colorValue = 0xFFF5F5F5,
    this.bodyType = VehicleType.sedan,
    this.fuelType = FuelType.gas,
  });

  final String id;
  final String make;
  final String model;
  final String year;
  final String plate;
  final int colorValue; // ARGB
  final VehicleType bodyType;
  final FuelType fuelType;

  String get colorName => DriverProfile.palette[colorValue] ?? '';

  /// "2022 Toyota Camry" — for garage cards / editor title.
  String get title =>
      [year, make, model].where((s) => s.trim().isNotEmpty).join(' ');

  /// "Red 2022 Toyota Camry · ABC-123" — same contract as the old
  /// DriverProfile.vehicleLine (color only shows alongside real vehicle info).
  String get vehicleLine {
    final vehicle = title;
    final desc = vehicle.isEmpty
        ? ''
        : [colorName, vehicle].where((s) => s.isNotEmpty).join(' ');
    final p = plate.trim();
    if (desc.isEmpty && p.isEmpty) return '';
    if (p.isEmpty) return desc;
    if (desc.isEmpty) return p;
    return '$desc · $p';
  }

  Vehicle copyWith({
    String? make,
    String? model,
    String? year,
    String? plate,
    int? colorValue,
    VehicleType? bodyType,
    FuelType? fuelType,
  }) =>
      Vehicle(
        id: id,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        plate: plate ?? this.plate,
        colorValue: colorValue ?? this.colorValue,
        bodyType: bodyType ?? this.bodyType,
        fuelType: fuelType ?? this.fuelType,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'year': year,
        'plate': plate,
        'color': colorValue,
        'body': bodyType.name,
        'fuel': fuelType.name,
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] is String ? j['id'] as String : '',
        make: j['make'] is String ? j['make'] as String : '',
        model: j['model'] is String ? j['model'] as String : '',
        year: j['year'] is String ? j['year'] as String : '',
        plate: j['plate'] is String ? j['plate'] as String : '',
        colorValue: j['color'] is int ? j['color'] as int : 0xFFF5F5F5,
        bodyType: VehicleType.values
                .where((t) => t.name == j['body'])
                .firstOrNull ??
            VehicleType.sedan,
        fuelType: FuelType.values
                .where((t) => t.name == j['fuel'])
                .firstOrNull ??
            FuelType.gas,
      );
}

/// The whole garage: vehicle list + which one is active. Immutable; every
/// mutation returns a new Garage. Storage format for `foxyco.garage.v1`.
class Garage {
  const Garage({this.vehicles = const [], this.activeId = ''});

  final List<Vehicle> vehicles;
  final String activeId;

  static const empty = Garage();

  /// Active vehicle; falls back to first when [activeId] is stale, null when
  /// the garage is empty (hero card hides).
  Vehicle? get active =>
      vehicles.where((v) => v.id == activeId).firstOrNull ?? vehicles.firstOrNull;

  Garage setActive(String id) =>
      vehicles.any((v) => v.id == id) ? Garage(vehicles: vehicles, activeId: id) : this;

  /// Replace by id, or append when unknown. Keeps activeId (first vehicle
  /// added to an empty garage becomes active).
  Garage upsert(Vehicle v) {
    final i = vehicles.indexWhere((e) => e.id == v.id);
    final next = [...vehicles];
    if (i >= 0) {
      next[i] = v;
    } else {
      next.add(v);
    }
    return Garage(vehicles: next, activeId: activeId.isEmpty ? v.id : activeId);
  }

  /// Deleting the active vehicle activates the next remaining one; deleting
  /// the last leaves an empty garage (spec M6 §4.3).
  Garage remove(String id) {
    final next = vehicles.where((v) => v.id != id).toList();
    final nextActive =
        next.any((v) => v.id == activeId) ? activeId : (next.firstOrNull?.id ?? '');
    return Garage(vehicles: next, activeId: nextActive);
  }

  Map<String, dynamic> toJson() => {
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'activeId': activeId,
      };

  factory Garage.fromJson(Map<String, dynamic> j) {
    final raw = j['vehicles'];
    final vehicles = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(Vehicle.fromJson).toList()
        : <Vehicle>[];
    return Garage(
      vehicles: vehicles,
      activeId: j['activeId'] is String ? j['activeId'] as String : '',
    );
  }

  /// One-way migration from the M5 single profile (spec M6 §4.1). A profile
  /// with no vehicle info (name only) yields an EMPTY garage — a default
  /// swatch on an otherwise-empty profile isn't a vehicle. Fuel defaults gas.
  factory Garage.fromLegacyProfile(DriverProfile p) {
    final hasVehicle = [p.vehicleMake, p.vehicleModel, p.vehicleYear, p.licensePlate]
        .any((s) => s.trim().isNotEmpty);
    if (!hasVehicle) return empty;
    final v = Vehicle(
      id: 'migrated-m5',
      make: p.vehicleMake,
      model: p.vehicleModel,
      year: p.vehicleYear,
      plate: p.licensePlate,
      colorValue: p.vehicleColor,
      bodyType: p.vehicleType,
    );
    return Garage(vehicles: [v], activeId: v.id);
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/garage_test.dart
```
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/garage.dart test/garage_test.dart
git commit -m "feat(m6): garage domain model with legacy-profile migration"
```

---

### Task 3: Garage controller + driver-name controller (persistence + migration)

**Files:**
- Create: `lib/ui/settings/garage_controller.dart`
- Test: `test/garage_controller_test.dart`

**Interfaces:**
- Consumes: `Garage`, `Vehicle`, `FuelType` (Task 2); `DriverProfile` (existing); `foxLogProvider` from `lib/services/fox_log.dart` (`ref.read(foxLogProvider).log(tag, message)`).
- Produces: `garageProvider` (`NotifierProvider<GarageController, Garage>`) with methods `Future<void> saveVehicle(Vehicle v)`, `Future<void> deleteVehicle(String id)`, `Future<void> setActive(String id)`; `activeVehicleProvider` (`Provider<Vehicle?>`); `driverNameProvider` (`NotifierProvider<DriverNameController, String>`) with `Future<void> setName(String v)`. Prefs keys: `GarageController.prefsKey = 'foxyco.garage.v1'`, `GarageController.legacyKey = 'foxyco.profile.v1'`, `DriverNameController.prefsKey = 'foxyco.driver.v1'`.
- NOTE: `profile_controller.dart` is NOT deleted here — `profile_card.dart` (Task 5) and `settings_screen.dart` (Task 8) still import it. It dies in Task 8.

- [ ] **Step 1: Write the failing tests** — `test/garage_controller_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted garage.v1 when present', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.prefsKey: jsonEncode(
        const Garage(
          vehicles: [Vehicle(id: 'x', make: 'Kia')],
          activeId: 'x',
        ).toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    expect(container.read(garageProvider).active!.make, 'Kia');
  });

  test('migrates legacy profile.v1 into garage.v1 exactly once', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.legacyKey: jsonEncode(
        const DriverProfile(name: 'Vamsi', vehicleMake: 'Toyota').toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    final g = container.read(garageProvider);
    expect(g.vehicles.length, 1);
    expect(g.active!.make, 'Toyota');
    expect(g.active!.fuelType, FuelType.gas);
    // Migration persisted — garage.v1 now exists, legacy key untouched.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GarageController.prefsKey), isNotNull);
    expect(prefs.getString(GarageController.legacyKey), isNotNull);
  });

  test('corrupt garage.v1 fails soft to empty', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.prefsKey: 'not json{{{',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    expect(container.read(garageProvider).vehicles, isEmpty);
  });

  test('saveVehicle persists and first vehicle becomes active', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    await container
        .read(garageProvider.notifier)
        .saveVehicle(const Vehicle(id: 'n1', make: 'Honda'));
    expect(container.read(garageProvider).active!.id, 'n1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GarageController.prefsKey), contains('Honda'));
  });

  test('deleteVehicle of active activates next; last delete empties', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(garageProvider.notifier);
    await _settle();
    await c.saveVehicle(const Vehicle(id: 'a', make: 'A'));
    await c.saveVehicle(const Vehicle(id: 'b', make: 'B'));
    await c.deleteVehicle('a');
    expect(container.read(garageProvider).active!.id, 'b');
    await c.deleteVehicle('b');
    expect(container.read(garageProvider).active, isNull);
  });

  test('driver name: loads foxyco.driver.v1, falls back to legacy name', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.legacyKey:
          jsonEncode(const DriverProfile(name: 'Vamsi').toJson()),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(driverNameProvider);
    await _settle();
    expect(container.read(driverNameProvider), 'Vamsi');
    // Seeded into its own key so the legacy blob is never needed again.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverNameController.prefsKey), 'Vamsi');
  });

  test('setName persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(driverNameProvider);
    await _settle();
    await container.read(driverNameProvider.notifier).setName('Neo');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverNameController.prefsKey), 'Neo');
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/garage_controller_test.dart
```
Expected: FAIL — `garage_controller.dart` not found.

- [ ] **Step 3: Implement `lib/ui/settings/garage_controller.dart`**

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../../services/fox_log.dart';

/// Holds the garage, persisted as one SharedPreferences JSON blob
/// (`foxyco.garage.v1`) — same fail-soft pattern as OfferLog. On first load,
/// if only the M5 single-profile blob exists, it's converted into a
/// one-vehicle garage (one-way, idempotent: once garage.v1 is written the
/// legacy key is never read again; it's kept on disk, harmless).
class GarageController extends Notifier<Garage> {
  static const prefsKey = 'foxyco.garage.v1';
  static const legacyKey = 'foxyco.profile.v1';

  @override
  Garage build() {
    _load();
    return Garage.empty;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        state = Garage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return;
      }
      final legacy = prefs.getString(legacyKey);
      if (legacy == null) return;
      final profile =
          DriverProfile.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
      final migrated = Garage.fromLegacyProfile(profile);
      state = migrated;
      if (migrated.vehicles.isNotEmpty) {
        await _save();
        ref.read(foxLogProvider).log('garage', 'migrated profile.v1 → garage.v1');
      }
    } catch (e) {
      // Fail-soft: empty garage, never crash (spec M6 §10).
      ref.read(foxLogProvider).log('garage', 'load failed, starting empty: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'save skipped: $e');
    }
  }

  /// Editor Save — insert or update, persist (spec M6 §4.3).
  Future<void> saveVehicle(Vehicle v) async {
    state = state.upsert(v);
    await _save();
  }

  /// Delete — active falls to next remaining, last delete empties the garage.
  Future<void> deleteVehicle(String id) async {
    state = state.remove(id);
    await _save();
  }

  /// Garage card tap — instant, persisted (spec M6 §4.2).
  Future<void> setActive(String id) async {
    state = state.setActive(id);
    await _save();
  }
}

final garageProvider =
    NotifierProvider<GarageController, Garage>(GarageController.new);

/// The vehicle the hero card + art render. Null → hero hides.
final activeVehicleProvider =
    Provider<Vehicle?>((ref) => ref.watch(garageProvider).active);

/// Driver name — the person, not the car (spec M6 §4.1). Own key; seeded from
/// the legacy profile's name on first run so nobody retypes it.
class DriverNameController extends Notifier<String> {
  static const prefsKey = 'foxyco.driver.v1';

  @override
  String build() {
    _load();
    return '';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        state = raw;
        return;
      }
      final legacy = prefs.getString(GarageController.legacyKey);
      if (legacy == null) return;
      final name = (jsonDecode(legacy) as Map<String, dynamic>)['name'];
      if (name is String && name.trim().isNotEmpty) {
        state = name;
        await prefs.setString(prefsKey, name);
      }
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'name load skipped: $e');
    }
  }

  /// Explicit save from the name card's check button (spec M6 §4.2 — no
  /// silent live-apply).
  Future<void> setName(String v) async {
    state = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, v);
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'name save skipped: $e');
    }
  }
}

final driverNameProvider =
    NotifierProvider<DriverNameController, String>(DriverNameController.new);
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/garage_controller_test.dart && flutter analyze
```
Expected: all PASS, analyze 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/garage_controller.dart test/garage_controller_test.dart
git commit -m "feat(m6): garage + driver-name controllers with v1 migration"
```

---

### Task 4: Premium car art (`VehicleArt`)

**Files:**
- Create: `lib/ui/theme/vehicle_art.dart`
- Test: `test/vehicle_art_test.dart`

**Interfaces:**
- Consumes: `VehicleType` (existing), `FuelType` (Task 2), tokens.
- Produces: `VehicleArt` widget — `const VehicleArt({required VehicleType bodyType, required Color color, FuelType fuelType = FuelType.gas, double width = 220})` (height derives as `width * 0.48`); exported painter class `VehicleArtPainter` (for test predicates). Swap-to-PNG later happens inside `VehicleArt` only (spec M6 §7 fallback).
- Old `VehiclePainter` in `profile_card.dart` dies in Task 5.

- [ ] **Step 1: Write the failing test** — `test/vehicle_art_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/theme/vehicle_art.dart';

void main() {
  for (final body in VehicleType.values) {
    testWidgets('renders $body without exceptions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: VehicleArt(
              bodyType: body,
              color: const Color(0xFFC62828),
              fuelType: FuelType.ev,
              width: 220,
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is VehicleArtPainter,
        ),
        findsOneWidget,
      );
    });
  }

  test('shouldRepaint only on visual change', () {
    const a = VehicleArtPainter(
      bodyType: VehicleType.sedan,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    const same = VehicleArtPainter(
      bodyType: VehicleType.sedan,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    const diff = VehicleArtPainter(
      bodyType: VehicleType.suv,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    expect(a.shouldRepaint(same), isFalse);
    expect(a.shouldRepaint(diff), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/vehicle_art_test.dart
```
Expected: FAIL — `vehicle_art.dart` not found.

- [ ] **Step 3: Implement `lib/ui/theme/vehicle_art.dart`** (complete file):

```dart
import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';

/// Premium layered vehicle art (spec M6 §7). One widget site so a later swap
/// to licensed PNGs stays contained. Aspect is fixed 220×106 (≈0.48) and all
/// painter coordinates are fractional, so the same art scales hero → thumb.
class VehicleArt extends StatelessWidget {
  const VehicleArt({
    super.key,
    required this.bodyType,
    required this.color,
    this.fuelType = FuelType.gas,
    this.width = 220,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.48,
      child: CustomPaint(
        painter: VehicleArtPainter(
          bodyType: bodyType,
          color: color,
          fuelType: fuelType,
        ),
      ),
    );
  }
}

/// Layer order (spec M6 §7): ground shadow → body gradient → roof highlight →
/// glass + reflection streak → wheels → seams/handles/lights → fuel badge.
/// Coordinates are fractions of (w, h); silhouettes lean 3/4 via a deeper
/// front (right) end and skewed glass, matching the reference cards' depth.
class VehicleArtPainter extends CustomPainter {
  const VehicleArtPainter({
    required this.bodyType,
    required this.color,
    required this.fuelType,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final (body, glass, wheels) = _silhouette(w, h);

    // 1. Ground shadow — soft blurred ellipse under the car.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * w, 0.92 * h),
        width: 0.86 * w,
        height: 0.10 * h,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. Body base — profile color, vertical light→dark gradient.
    final bodyRect = body.getBounds();
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
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bodyRect),
    );

    // 3. Roofline/hood highlight sweep — clipped to the body.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTRB(0.15 * w, 0, 0.75 * w, 0.45 * h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(0.15 * w, 0, 0.75 * w, 0.45 * h)),
    );
    // Rocker-panel darkening near the ground.
    canvas.drawRect(
      Rect.fromLTRB(0, 0.72 * h, w, h),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();

    // 4. Glass — dark blue-grey with a diagonal reflection streak.
    if (!glass.getBounds().isEmpty) {
      canvas.drawPath(glass, Paint()..color = const Color(0xE61C2733));
      canvas.save();
      canvas.clipPath(glass);
      final gb = glass.getBounds();
      canvas.drawPath(
        Path()
          ..moveTo(gb.left + gb.width * 0.15, gb.top)
          ..lineTo(gb.left + gb.width * 0.35, gb.top)
          ..lineTo(gb.left + gb.width * 0.20, gb.bottom)
          ..lineTo(gb.left, gb.bottom)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.14),
      );
      canvas.restore();
    }

    // 5. Wheels — tire ring, rim with spoke hints, hub dot.
    final tire = Paint()..color = const Color(0xFF15171A);
    final rim = Paint()
      ..color = const Color(0xFFAAB2BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.022 * w;
    final hub = Paint()..color = const Color(0xFF5F6770);
    for (final c in wheels) {
      final center = Offset(c.dx * w, c.dy * h);
      final r = 0.085 * w;
      canvas.drawCircle(center, r, tire);
      canvas.drawCircle(center, r * 0.62, rim);
      for (var i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * 3.14159 * 2 / 5);
        canvas.drawLine(
          Offset.zero,
          Offset(0, -r * 0.58),
          Paint()
            ..color = const Color(0xFF737B85)
            ..strokeWidth = 0.010 * w,
        );
        canvas.restore();
      }
      canvas.drawCircle(center, r * 0.16, hub);
    }

    // 6. Detail pass — door seam, handle tick, light glints.
    canvas.save();
    canvas.clipPath(body);
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0.52 * w, 0.42 * h),
      Offset(0.50 * w, 0.74 * h),
      seam,
    );
    canvas.drawLine(
      Offset(0.55 * w, 0.50 * h),
      Offset(0.61 * w, 0.50 * h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.012 * w
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    // Headlight (front = right), taillight (rear = left).
    canvas.drawCircle(
      Offset(0.945 * w, 0.55 * h),
      0.020 * w,
      Paint()
        ..color = const Color(0xFFFFE9B8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(0.055 * w, 0.52 * h),
      0.016 * w,
      Paint()
        ..color = const Color(0xFFE8493F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 7. Fuel badge near the rear wheel (spec: EV bolt, hybrid two-tone dot).
    if (fuelType == FuelType.ev) {
      final c = Offset(0.155 * w, 0.38 * h);
      canvas.drawCircle(c, 0.045 * w, Paint()..color = const Color(0xFF1D2B22));
      final bolt = Path()
        ..moveTo(c.dx + 0.010 * w, c.dy - 0.030 * w)
        ..lineTo(c.dx - 0.014 * w, c.dy + 0.004 * w)
        ..lineTo(c.dx - 0.001 * w, c.dy + 0.004 * w)
        ..lineTo(c.dx - 0.010 * w, c.dy + 0.030 * w)
        ..lineTo(c.dx + 0.014 * w, c.dy - 0.004 * w)
        ..lineTo(c.dx + 0.001 * w, c.dy - 0.004 * w)
        ..close();
      canvas.drawPath(bolt, Paint()..color = const Color(0xFF6FE3A1));
    } else if (fuelType == FuelType.hybrid) {
      final c = Offset(0.155 * w, 0.38 * h);
      canvas.drawCircle(c, 0.028 * w, Paint()..color = const Color(0xFF6FE3A1));
      canvas.drawCircle(
        c,
        0.028 * w,
        Paint()
          ..color = const Color(0xFF1D2B22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012 * w,
      );
    }
  }

  /// Body + glass paths and wheel centers (fractions), per body type.
  (Path, Path, List<Offset>) _silhouette(double w, double h) {
    Path body;
    Path glass;
    var wheels = const [Offset(0.26, 0.82), Offset(0.78, 0.82)];
    switch (bodyType) {
      case VehicleType.sedan:
        body = Path()
          ..moveTo(0.04 * w, 0.74 * h)
          ..quadraticBezierTo(0.03 * w, 0.56 * h, 0.12 * w, 0.52 * h)
          ..lineTo(0.30 * w, 0.48 * h)
          ..quadraticBezierTo(0.38 * w, 0.24 * h, 0.52 * w, 0.22 * h)
          ..quadraticBezierTo(0.66 * w, 0.22 * h, 0.74 * w, 0.44 * h)
          ..lineTo(0.90 * w, 0.50 * h)
          ..quadraticBezierTo(0.97 * w, 0.54 * h, 0.96 * w, 0.74 * h)
          ..close();
        glass = Path()
          ..moveTo(0.38 * w, 0.28 * h)
          ..quadraticBezierTo(0.52 * w, 0.26 * h, 0.62 * w, 0.28 * h)
          ..lineTo(0.70 * w, 0.44 * h)
          ..lineTo(0.33 * w, 0.46 * h)
          ..close();
      case VehicleType.suv:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.44 * h)
          ..quadraticBezierTo(0.08 * w, 0.38 * h, 0.18 * w, 0.36 * h)
          ..quadraticBezierTo(0.26 * w, 0.16 * h, 0.42 * w, 0.15 * h)
          ..lineTo(0.72 * w, 0.15 * h)
          ..quadraticBezierTo(0.82 * w, 0.18 * h, 0.87 * w, 0.40 * h)
          ..quadraticBezierTo(0.96 * w, 0.44 * h, 0.96 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.31 * w, 0.20 * h)
          ..lineTo(0.72 * w, 0.20 * h)
          ..lineTo(0.80 * w, 0.38 * h)
          ..lineTo(0.24 * w, 0.38 * h)
          ..close();
      case VehicleType.hatchback:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..quadraticBezierTo(0.04 * w, 0.50 * h, 0.14 * w, 0.44 * h)
          ..quadraticBezierTo(0.24 * w, 0.22 * h, 0.44 * w, 0.20 * h)
          ..lineTo(0.62 * w, 0.20 * h)
          ..quadraticBezierTo(0.80 * w, 0.24 * h, 0.88 * w, 0.48 * h)
          ..quadraticBezierTo(0.95 * w, 0.52 * h, 0.94 * w, 0.75 * h)
          ..close();
        glass = Path()
          ..moveTo(0.26 * w, 0.26 * h)
          ..lineTo(0.60 * w, 0.25 * h)
          ..lineTo(0.76 * w, 0.44 * h)
          ..lineTo(0.20 * w, 0.44 * h)
          ..close();
      case VehicleType.pickup:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.46 * h)
          ..lineTo(0.34 * w, 0.44 * h)
          ..lineTo(0.38 * w, 0.20 * h)
          ..lineTo(0.62 * w, 0.20 * h)
          ..quadraticBezierTo(0.72 * w, 0.22 * h, 0.76 * w, 0.44 * h)
          ..quadraticBezierTo(0.94 * w, 0.46 * h, 0.95 * w, 0.56 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.42 * w, 0.24 * h)
          ..lineTo(0.60 * w, 0.24 * h)
          ..lineTo(0.66 * w, 0.42 * h)
          ..lineTo(0.40 * w, 0.42 * h)
          ..close();
      case VehicleType.van:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.28 * h)
          ..quadraticBezierTo(0.06 * w, 0.14 * h, 0.20 * w, 0.13 * h)
          ..lineTo(0.80 * w, 0.13 * h)
          ..quadraticBezierTo(0.92 * w, 0.16 * h, 0.95 * w, 0.36 * h)
          ..lineTo(0.96 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.16 * w, 0.20 * h)
          ..lineTo(0.84 * w, 0.20 * h)
          ..lineTo(0.89 * w, 0.36 * h)
          ..lineTo(0.13 * w, 0.36 * h)
          ..close();
      case VehicleType.motorbike:
        body = Path()
          ..moveTo(0.14 * w, 0.66 * h)
          ..quadraticBezierTo(0.24 * w, 0.42 * h, 0.42 * w, 0.40 * h)
          ..quadraticBezierTo(0.52 * w, 0.24 * h, 0.62 * w, 0.24 * h)
          ..lineTo(0.68 * w, 0.30 * h)
          ..quadraticBezierTo(0.62 * w, 0.44 * h, 0.72 * w, 0.48 * h)
          ..quadraticBezierTo(0.84 * w, 0.52 * h, 0.85 * w, 0.66 * h)
          ..close();
        glass = Path(); // no glass on a bike
        wheels = const [Offset(0.22, 0.78), Offset(0.80, 0.78)];
    }
    return (body, glass, wheels);
  }

  @override
  bool shouldRepaint(VehicleArtPainter old) =>
      old.bodyType != bodyType ||
      old.color != color ||
      old.fuelType != fuelType;
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/vehicle_art_test.dart && flutter analyze
```
Expected: all PASS, 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/theme/vehicle_art.dart test/vehicle_art_test.dart
git commit -m "feat(m6): layered premium VehicleArt painters (6 body types + fuel badges)"
```

---

### Task 5: Hero profile card rebuild (greeting bands + garage + VehicleArt)

**Files:**
- Modify: `lib/ui/home/profile_card.dart` (full rewrite)
- Test: `test/profile_card_test.dart` (rewrite)

**Interfaces:**
- Consumes: `activeVehicleProvider`, `driverNameProvider` (Task 3); `VehicleArt` (Task 4); tokens.
- Produces: `ProfileCard` (same widget name, same Home usage); static `String greetingFor(int hour)` → `'Good morning' | 'Good afternoon' | 'Good evening' | 'Late shift'` (public for tests).
- Old `VehiclePainter` + `_greeting` deleted with the rewrite.

- [ ] **Step 1: Rewrite the test** — `test/profile_card_test.dart` (replace whole file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/home/profile_card.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/theme/vehicle_art.dart';

class _FixedGarage extends GarageController {
  _FixedGarage(this._g);
  final Garage _g;
  @override
  Garage build() => _g;
}

class _FixedName extends DriverNameController {
  _FixedName(this._n);
  final String _n;
  @override
  String build() => _n;
}

Widget _app(String name, Garage g) => ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _FixedGarage(g)),
        driverNameProvider.overrideWith(() => _FixedName(name)),
      ],
      child: const MaterialApp(home: Scaffold(body: ProfileCard())),
    );

void main() {
  test('greeting bands: 05/12/17/22 boundaries (spec M6 §3.1)', () {
    expect(ProfileCard.greetingFor(5), 'Good morning');
    expect(ProfileCard.greetingFor(11), 'Good morning');
    expect(ProfileCard.greetingFor(12), 'Good afternoon');
    expect(ProfileCard.greetingFor(16), 'Good afternoon');
    expect(ProfileCard.greetingFor(17), 'Good evening');
    expect(ProfileCard.greetingFor(21), 'Good evening');
    expect(ProfileCard.greetingFor(22), 'Late shift');
    expect(ProfileCard.greetingFor(1), 'Late shift');
    expect(ProfileCard.greetingFor(4), 'Late shift');
  });

  testWidgets('no name → no card', (tester) async {
    await tester.pumpWidget(_app('', Garage.empty));
    await tester.pump();
    expect(find.byType(VehicleArt), findsNothing);
    expect(find.textContaining(','), findsNothing);
  });

  testWidgets('name + active vehicle → greeting, vehicle line, art, EV badge',
      (tester) async {
    const g = Garage(
      vehicles: [
        Vehicle(
          id: 'a',
          make: 'Toyota',
          model: 'Camry',
          year: '2022',
          plate: 'ABC-123',
          colorValue: 0xFFC62828,
          bodyType: VehicleType.sedan,
          fuelType: FuelType.ev,
        ),
      ],
      activeId: 'a',
    );
    await tester.pumpWidget(_app('Vamsi', g));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    expect(find.textContaining('Red 2022 Toyota Camry'), findsOneWidget);
    expect(find.byType(VehicleArt), findsOneWidget);
    expect(find.text('⚡ EV'), findsOneWidget);
  });

  testWidgets('name but empty garage → card shows greeting, no art',
      (tester) async {
    await tester.pumpWidget(_app('Vamsi', Garage.empty));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    expect(find.byType(VehicleArt), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/profile_card_test.dart
```
Expected: FAIL — `greetingFor` undefined / garage imports missing.

- [ ] **Step 3: Rewrite `lib/ui/home/profile_card.dart`** (replace whole file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/garage.dart';
import '../settings/garage_controller.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_art.dart';

/// Home hero profile card (spec M6 §3.1): banded greeting (incl. the 22–04
/// "Late shift" fix), active-vehicle line + fuel badge, premium VehicleArt on
/// a dark gradient stage. Hidden entirely until the driver gives a name.
/// Entrance fade+slide once; slow sheen loop after — both skipped when the OS
/// asks for reduced motion.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  /// Greeting band for [hour] (spec M6 §3.1). 22–04 is the night-driver fix:
  /// "Good morning" at 1 AM read as broken to the people actually working.
  static String greetingFor(int hour) {
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Late shift';
  }

  static String _fuelBadge(FuelType f) => switch (f) {
        FuelType.ev => '⚡ EV',
        FuelType.hybrid => '● Hybrid',
        FuelType.gas => '',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(driverNameProvider).trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final vehicle = ref.watch(activeVehicleProvider);

    final card = Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greetingFor(DateTime.now().hour)}, $name',
            style: const TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: FoxColors.cream,
            ),
          ),
          if (vehicle != null) ...[
            if (vehicle.vehicleLine.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      vehicle.vehicleLine,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_fuelBadge(vehicle.fuelType).isNotEmpty) ...[
                    const SizedBox(width: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FoxColors.bgSurface2,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: FoxColors.borderSoft),
                      ),
                      child: Text(
                        _fuelBadge(vehicle.fuelType),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: VerdictColors.good,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: Gap.md),
            Center(
              child: VehicleArt(
                bodyType: vehicle.bodyType,
                color: Color(vehicle.colorValue),
                fuelType: vehicle.fuelType,
                width: 230,
              ),
            ),
          ],
        ],
      ),
    );

    // Reduced motion: static card, no entrance, no sheen.
    if (MediaQuery.of(context).disableAnimations) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: card,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: _AnimatedEntrance(child: _SheenLoop(child: card)),
    );
  }
}

/// One-shot fade + slide-up on first build.
class _AnimatedEntrance extends StatefulWidget {
  const _AnimatedEntrance({required this.child});
  final Widget child;

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  late final _fade = CurvedAnimation(parent: _c, curve: Motion.curve);
  late final _slide =
      Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fade);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Slow low-opacity sheen sweeping the card; long period, subtle.
class _SheenLoop extends StatefulWidget {
  const _SheenLoop({required this.child});
  final Widget child;

  @override
  State<_SheenLoop> createState() => _SheenLoopState();
}

class _SheenLoopState extends State<_SheenLoop>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.5 + 3 * _c.value, -0.3),
          end: Alignment(-0.5 + 3 * _c.value, 0.3),
          colors: const [
            Colors.transparent,
            Color(0x14FFFFFF),
            Colors.transparent,
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/profile_card_test.dart && flutter analyze
```
Expected: all PASS, 0 issues. NOTE: `flutter test` full run may now fail in `settings_screen_test.dart` if it exercised `VehiclePainter` — it doesn't (checked); the profile FORM still uses `profileProvider`, untouched until Task 8.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/home/profile_card.dart test/profile_card_test.dart
git commit -m "feat(m6): hero card rebuild — greeting bands, garage vehicle, VehicleArt"
```

---

### Task 6: Slide-to-go-live control

**Files:**
- Create: `lib/ui/home/slide_to_live.dart`
- Modify: `lib/ui/home/home_screen.dart` (swap `_ActiveButton` for `SlideToLive`)
- Test: `test/slide_to_live_test.dart`

**Interfaces:**
- Consumes: `WatchStatus` from `lib/ui/home/dashboard_state.dart`; tokens; `HapticFeedback` (flutter/services).
- Produces: `SlideToLive` — `const SlideToLive({required WatchStatus status, required VoidCallback onStart, required VoidCallback onStop, required VoidCallback onFix})`. Full-width control replacing the hero's `_ActiveButton` row slot. Commit threshold constant `SlideToLive.commitFraction = 0.85`.
- Start/stop wire to the EXACT same calls the button used: `controller.startMonitoring` / `controller.stopMonitoring` / `controller.requestMissingPermissions` (blocked). Pause stays on bubble long-press — untouched.

- [ ] **Step 1: Write the failing test** — `test/slide_to_live_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/home/slide_to_live.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.initial});
  final WatchStatus initial;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late WatchStatus status = widget.initial;
  int starts = 0, stops = 0, fixes = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SlideToLive(
                status: status,
                onStart: () => setState(() {
                  starts++;
                  status = WatchStatus.watching;
                }),
                onStop: () => setState(() {
                  stops++;
                  status = WatchStatus.stopped;
                }),
                onFix: () => fixes++,
              ),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('full drag right commits start', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    final thumb = find.byKey(const ValueKey('slide-thumb'));
    expect(thumb, findsOneWidget);
    await tester.drag(thumb, const Offset(320, 0));
    await tester.pumpAndSettle();
    expect(key.currentState!.starts, 1);
  });

  testWidgets('short drag springs back, no start', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    await tester.drag(
        find.byKey(const ValueKey('slide-thumb')), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(key.currentState!.starts, 0);
  });

  testWidgets('watching shows live bar; drag back stops', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.watching));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final stopThumb = find.byKey(const ValueKey('slide-stop-thumb'));
    expect(stopThumb, findsOneWidget);
    await tester.drag(stopThumb, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(key.currentState!.stops, 1);
  });

  testWidgets('semantic button path works without sliding (a11y)',
      (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    final semantics = tester.getSemantics(
        find.byKey(const ValueKey('slide-to-live-semantics')));
    expect(semantics.label, contains('Go live'));
    // Tap-activation path (SemanticsAction.tap wired to onStart).
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(semantics.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(key.currentState!.starts, 1);
  });

  testWidgets('blocked state routes to onFix via semantics tap',
      (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.blocked));
    await tester.pump();
    final semantics = tester.getSemantics(
        find.byKey(const ValueKey('slide-to-live-semantics')));
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(semantics.id, SemanticsAction.tap);
    await tester.pump();
    expect(key.currentState!.fixes, 1);
  });
}
```

Add import to the test: `import 'package:flutter/rendering.dart';` (for `SemanticsAction`).

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/slide_to_live_test.dart
```
Expected: FAIL — `slide_to_live.dart` not found.

- [ ] **Step 3: Implement `lib/ui/home/slide_to_live.dart`** (complete file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'dashboard_state.dart';

/// Slide-to-go-live (spec M6 §3.2). Stopped/blocked: a pill track with an
/// orange bolt thumb — drag ≥85% commits start (haptic), less springs back.
/// Watching/paused: morphs into a slim live bar with a pulsing dot and the
/// reverse affordance — drag the thumb back left to stop. Slide is the visual
/// affordance, not the only path: the whole control is a semantic button.
class SlideToLive extends StatefulWidget {
  const SlideToLive({
    super.key,
    required this.status,
    required this.onStart,
    required this.onStop,
    required this.onFix,
  });

  final WatchStatus status;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onFix;

  static const commitFraction = 0.85;

  @override
  State<SlideToLive> createState() => _SlideToLiveState();
}

class _SlideToLiveState extends State<SlideToLive>
    with SingleTickerProviderStateMixin {
  double _drag = 0; // 0..1 travel fraction while dragging
  bool _dragging = false;
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: Motion.morph,
  );

  static const _height = 56.0;
  static const _thumb = 44.0;

  bool get _running =>
      widget.status == WatchStatus.watching ||
      widget.status == WatchStatus.paused;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _release(double travel) {
    if (travel >= SlideToLive.commitFraction) {
      HapticFeedback.mediumImpact();
      setState(() {
        _drag = 0;
        _dragging = false;
      });
      _running ? widget.onStop() : widget.onStart();
    } else {
      HapticFeedback.lightImpact();
      // Spring back with overshoot (user-driven gesture → spring allowed).
      final from = _drag;
      _spring
        ..reset()
        ..addListener(_onSpringTick(from))
        ..forward().whenComplete(() {
          _spring.clearListeners();
          if (mounted) setState(() => _dragging = false);
        });
    }
  }

  VoidCallback _onSpringTick(double from) => () {
        final t = Motion.spring.transform(_spring.value);
        if (mounted) setState(() => _drag = from * (1 - t));
      };

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final blocked = widget.status == WatchStatus.blocked;

    final label = blocked
        ? 'Grant access'
        : _running
            ? 'Stop'
            : 'Go live';

    return Semantics(
      key: const ValueKey('slide-to-live-semantics'),
      button: true,
      label: label,
      onTap: blocked
          ? widget.onFix
          : _running
              ? widget.onStop
              : widget.onStart,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: reduced ? Duration.zero : Motion.morph,
          switchInCurve: Motion.curve,
          switchOutCurve: Motion.curve,
          child: _running
              ? _liveBar(context, reduced)
              : _slideTrack(context, blocked),
        ),
      ),
    );
  }

  /// Stopped/blocked: the slide track.
  Widget _slideTrack(BuildContext context, bool blocked) {
    return LayoutBuilder(
      key: const ValueKey('track'),
      builder: (context, c) {
        final travelPx = c.maxWidth - _thumb - 12;
        final x = _drag * travelPx;
        return GestureDetector(
          onTap: blocked ? widget.onFix : null,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: FoxColors.bgSurface2,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: FoxColors.border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Orange fill rising behind the thumb.
                AnimatedContainer(
                  duration: _dragging ? Duration.zero : Motion.fast,
                  width: x + _thumb + 6,
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    gradient: LinearGradient(
                      colors: [
                        FoxColors.brandFoxDeep
                            .withValues(alpha: 0.0 + 0.6 * _drag),
                        FoxColors.brandFox.withValues(alpha: 0.15 + 0.7 * _drag),
                      ],
                    ),
                  ),
                ),
                // Label fades as fill passes it.
                Center(
                  child: Opacity(
                    opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                    child: Text(
                      blocked ? 'Grant access to go live' : 'Slide to go live',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: 6 + x,
                  child: GestureDetector(
                    key: const ValueKey('slide-thumb'),
                    onHorizontalDragStart: blocked
                        ? null
                        : (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: blocked
                        ? null
                        : (d) => setState(() => _drag =
                            (_drag + d.delta.dx / travelPx).clamp(0.0, 1.0)),
                    onHorizontalDragEnd:
                        blocked ? null : (_) => _release(_drag),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: blocked
                            ? FoxColors.textDisabled
                            : FoxColors.brandFox,
                        shape: BoxShape.circle,
                        boxShadow: blocked ? null : Shadows.glow,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Watching/paused: slim live bar, pulsing dot, slide-back-to-stop.
  Widget _liveBar(BuildContext context, bool reduced) {
    return LayoutBuilder(
      key: const ValueKey('live'),
      builder: (context, c) {
        final travelPx = c.maxWidth - _thumb - 12;
        // Stop-drag travels RIGHT→LEFT: _drag 0 = thumb parked right.
        final x = travelPx * (1 - _drag);
        final paused = widget.status == WatchStatus.paused;
        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: FoxColors.brandFox.withValues(alpha: 0.4),
            ),
            boxShadow: reduced ? null : Shadows.glowSoft,
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Gap.md + Gap.xs),
                child: Row(
                  children: [
                    _PulsingDot(reduced: reduced || paused),
                    const SizedBox(width: Gap.sm),
                    Text(
                      paused ? 'Paused' : 'Live',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.cream,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Opacity(
                      opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                      child: const Text(
                        '· slide back to stop',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FoxColors.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 6 + x,
                child: GestureDetector(
                  key: const ValueKey('slide-stop-thumb'),
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) => setState(() => _drag =
                      (_drag - d.delta.dx / travelPx).clamp(0.0, 1.0)),
                  onHorizontalDragEnd: (_) => _release(_drag),
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: FoxColors.brandFox,
                      shape: BoxShape.circle,
                      boxShadow: reduced ? null : Shadows.glowSoft,
                    ),
                    child: const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pulsing live dot; static when reduced motion or paused.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.reduced});
  final bool reduced;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.reduced && _c.isAnimating) _c.stop();
    if (!widget.reduced && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: FoxColors.brandFox,
          shape: BoxShape.circle,
          boxShadow: widget.reduced
              ? null
              : [
                  BoxShadow(
                    color: FoxColors.brandFox
                        .withValues(alpha: 0.3 + 0.4 * _c.value),
                    blurRadius: 6 + 8 * _c.value,
                  ),
                ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire into `lib/ui/home/home_screen.dart`**

In `_Hero`: delete the `_ActiveButton` class and its usage. Change `_Hero`'s constructor params `onToggleActive`/`onFix` → keep `onFix`, replace `onToggleActive` with three callbacks OR simpler: pass through. Replace the `Row` containing the big count + `_ActiveButton` with count-only `Column`, and add the slider full-width below `_SegLegend`:

```dart
          const SizedBox(height: Gap.md + Gap.xs),
          _SegBar(tally: tally),
          const SizedBox(height: Gap.sm + Gap.xs),
          _SegLegend(tally: tally),
          const SizedBox(height: Gap.md),
          SlideToLive(
            status: status,
            onStart: onStart,
            onStop: onStop,
            onFix: onFix,
          ),
```

`_Hero` signature becomes:

```dart
  const _Hero({
    required this.status,
    required this.tally,
    required this.platforms,
    required this.onStart,
    required this.onStop,
    required this.onFix,
  });

  final WatchStatus status;
  final Tally tally;
  final List<String> platforms;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onFix;
```

Call-site in `HomeScreen.build`:

```dart
        _Hero(
          status: state.status,
          tally: ref.watch(todayTallyProvider),
          platforms: ref
              .watch(settingsProvider)
              .watchedApps
              .map((p) => p.label)
              .toList(),
          onStart: controller.startMonitoring,
          onStop: controller.stopMonitoring,
          onFix: controller.requestMissingPermissions,
        ),
```

Add import: `import 'slide_to_live.dart';` and `import 'package:flutter/services.dart';` is NOT needed in home_screen.

- [ ] **Step 5: Run tests**

```bash
flutter test test/slide_to_live_test.dart && flutter test && flutter analyze
```
Expected: new tests PASS; `widget_test.dart`/`dashboard_*` still PASS (start/stop semantics unchanged). 0 analyze issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home/slide_to_live.dart lib/ui/home/home_screen.dart test/slide_to_live_test.dart
git commit -m "feat(m6): slide-to-go-live control replaces Go Live button"
```

---

### Task 7: Home status card + last offer restyle (count-up, monogram chips, seg-bar animation, glow strip)

**Files:**
- Modify: `lib/ui/home/home_screen.dart`
- Test: `test/home_polish_test.dart` (new)

**Interfaces:**
- Consumes: tokens (incl. `bgSurface2`, `Shadows.glow`), `Tally`, existing providers.
- Produces: public-for-test `CountUpText` widget in `home_screen.dart`? NO — keep private; test via rendered text. New shared widget `AppMonogram` in `lib/ui/theme/verdict_style.dart`? NO — Task 9 (History) needs the same monogram; so: Create `lib/ui/theme/platform_badge.dart` here with `PlatformBadge` — `const PlatformBadge({required GigPlatform platform, double size = 22, bool active = true})` — lettered roundel (U/L/H) on platform color. History (Task 9) consumes it.

- [ ] **Step 1: Write the failing test** — `test/home_polish_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/ui/theme/platform_badge.dart';

void main() {
  testWidgets('PlatformBadge shows the platform initial', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(children: [
          PlatformBadge(platform: GigPlatform.uber),
          PlatformBadge(platform: GigPlatform.lyft),
          PlatformBadge(platform: GigPlatform.hopp),
        ]),
      ),
    ));
    expect(find.text('U'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
  });

  testWidgets('inactive badge dims', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PlatformBadge(platform: GigPlatform.uber, active: false),
      ),
    ));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('U'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1.0));
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/home_polish_test.dart
```
Expected: FAIL — `platform_badge.dart` not found.

- [ ] **Step 3: Create `lib/ui/theme/platform_badge.dart`**

```dart
import 'package:flutter/material.dart';

import '../../domain/platform.dart';
import 'tokens.dart';

/// Platform monogram roundel (spec M6 §3.3/§5.2): lettered badge on the
/// platform color — reads at a glance where a colored dot didn't.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({
    super.key,
    required this.platform,
    this.size = 22,
    this.active = true,
  });

  final GigPlatform platform;
  final double size;
  final bool active;

  static const _colors = {
    GigPlatform.uber: FoxColors.uber,
    GigPlatform.lyft: FoxColors.lyft,
    GigPlatform.hopp: FoxColors.hopp,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[platform] ?? FoxColors.textDisabled;
    // Uber's badge is near-white → dark letter; others take a light letter.
    final letterColor =
        color.computeLuminance() > 0.5 ? FoxColors.bgBase : Colors.white;
    return Opacity(
      opacity: active ? 1.0 : 0.45,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 1.0 : 0.6),
          shape: BoxShape.circle,
        ),
        child: Text(
          platform.label[0].toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: letterColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Restyle `lib/ui/home/home_screen.dart`** (edits within existing classes):

a) **App chips → monogram badges.** In `_Hero`, replace the `for (final p in platforms) ... _AppTag(p)` loop's parameter plumbing: change `_Hero.platforms` from `List<String>` to `List<GigPlatform>` and call-site to `.watchedApps.toList()`. Replace `_AppTag(p)` with `PlatformBadge(platform: p)` and delete the `_AppTag` class. Add imports `import '../../domain/platform.dart';` and `import '../theme/platform_badge.dart';`.

b) **Count-up on the big number.** Replace the big `Text('$total', ...)` with:

```dart
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: total),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : Motion.count,
                    curve: Motion.curve,
                    builder: (context, v, _) => Text(
                      '$v',
                      style: const TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 56,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.5,
                        color: FoxColors.cream,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
```

c) **Seg-bar: taller + animated widths.** Replace `_SegBar.build` body:

```dart
  @override
  Widget build(BuildContext context) {
    final total = tally.good + tally.ok + tally.bad;
    final reduced = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        height: 16,
        color: FoxColors.cream.withValues(alpha: 0.08),
        child: total == 0
            ? null // zero state: faint track only (spec M6 §3.3)
            : LayoutBuilder(
                builder: (context, c) => Row(
                  children: [
                    for (final (count, color) in [
                      (tally.good, VerdictColors.good),
                      (tally.ok, VerdictColors.ok),
                      (tally.bad, VerdictColors.bad),
                    ])
                      AnimatedContainer(
                        duration: reduced ? Duration.zero : Motion.base,
                        curve: Motion.curve,
                        width: c.maxWidth * count / total,
                        color: color,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
```

d) **good/ok/bad → stat chips.** Replace `_SegLegend`/`_LegendItem` build internals — each item becomes a small well:

```dart
class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.count, this.label);
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FoxColors.cream.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: FoxColors.cream.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: const TextStyle(
                    color: FoxColors.cream,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(text: ' $label'),
              ],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FoxColors.cream.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

(`_SegLegend` keeps its Row, spacing `Gap.sm`.)

e) **Last offer card: verdict edge glow strip.** In `_Ticket`, the verdict spine Container gets a glow:

```dart
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.color.withValues(alpha: 0.55),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
```

f) **`_Perforation` notch color**: `FoxColors.bgBase` already token-based — dark now, correct, leave.

- [ ] **Step 5: Run tests**

```bash
flutter test && flutter analyze
```
Expected: all PASS (widget_test pumps HomeScreen — count-up settles with pumpAndSettle; if `widget_test.dart` uses bare `pump`, totals start at 0 — check and use `pumpAndSettle` there if it asserts the total), 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home/home_screen.dart lib/ui/theme/platform_badge.dart test/home_polish_test.dart
git commit -m "feat(m6): status-card polish — monogram badges, count-up, animated seg-bar, glow ticket"
```

---

### Task 8: Settings → Garage UI + vehicle editor + settings restyle

**Files:**
- Create: `lib/ui/settings/vehicle_editor_screen.dart`
- Modify: `lib/ui/settings/settings_screen.dart` (garage section replaces `_ProfileForm`; dark cards + icons + stagger)
- Modify: `lib/router.dart` (editor route)
- Delete: `lib/ui/settings/profile_controller.dart`
- Test: `test/vehicle_editor_test.dart` (new), `test/settings_screen_test.dart` (update)

**Interfaces:**
- Consumes: `garageProvider`, `driverNameProvider`, `activeVehicleProvider` (Task 3); `VehicleArt` (Task 4); `Vehicle`, `FuelType`, `VehicleType`; go_router.
- Produces: route `/vehicle-editor` taking `Vehicle?` via `state.extra` (null = add-new); `VehicleEditorScreen` — `const VehicleEditorScreen({Vehicle? initial})`. Save validates make-or-model non-empty AND year empty-or-4-digit; nothing persists until Save (spec M6 §4.3).

- [ ] **Step 1: Write the failing tests** — `test/vehicle_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/vehicle_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) =>
    ProviderScope(child: MaterialApp(home: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('save disabled until make or model present', (tester) async {
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.pump();
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(
        find.byKey(const ValueKey('editor-make')), 'Toyota');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
  });

  testWidgets('bad year blocks save', (tester) async {
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('editor-make')), 'Toyota');
    await tester.enterText(
        find.byKey(const ValueKey('editor-year')), '20x2');
    await tester.pump();
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
  });

  testWidgets('nothing persists until Save; Save writes to garage',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const VehicleEditorScreen();
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('editor-make')), 'Honda');
    await tester.pump();
    expect(container.read(garageProvider).vehicles, isEmpty); // not yet
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles.length, 1);
    expect(container.read(garageProvider).active!.make, 'Honda');
  });

  testWidgets('editing existing vehicle seeds fields; delete removes it',
      (tester) async {
    const existing = Vehicle(id: 'v1', make: 'Kia', model: 'EV6');
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(builder: (context) {
            container = ProviderScope.containerOf(context);
            return const VehicleEditorScreen(initial: existing);
          }),
        ),
      ),
    );
    await tester.pump();
    await container
        .read(garageProvider.notifier)
        .saveVehicle(existing); // seed the garage
    expect(find.widgetWithText(TextField, 'Kia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/vehicle_editor_test.dart
```
Expected: FAIL — `vehicle_editor_screen.dart` not found.

- [ ] **Step 3: Implement `lib/ui/settings/vehicle_editor_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_art.dart';
import 'garage_controller.dart';

/// Full-screen vehicle editor (spec M6 §4.3). Local draft state only —
/// NOTHING touches the garage until Save; Cancel/back discards. Live art
/// preview re-tints/re-shapes as the driver edits. Delete (existing vehicles)
/// confirms first; the controller handles active-fallback.
class VehicleEditorScreen extends ConsumerStatefulWidget {
  const VehicleEditorScreen({super.key, this.initial});

  /// Null = add-new.
  final Vehicle? initial;

  @override
  ConsumerState<VehicleEditorScreen> createState() =>
      _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends ConsumerState<VehicleEditorScreen> {
  late final _make = TextEditingController(text: widget.initial?.make ?? '');
  late final _model = TextEditingController(text: widget.initial?.model ?? '');
  late final _year = TextEditingController(text: widget.initial?.year ?? '');
  late final _plate = TextEditingController(text: widget.initial?.plate ?? '');
  late int _color = widget.initial?.colorValue ?? 0xFFF5F5F5;
  late VehicleType _body = widget.initial?.bodyType ?? VehicleType.sedan;
  late FuelType _fuel = widget.initial?.fuelType ?? FuelType.gas;

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _yearOk {
    final y = _year.text.trim();
    return y.isEmpty || RegExp(r'^\d{4}$').hasMatch(y);
  }

  bool get _canSave =>
      (_make.text.trim().isNotEmpty || _model.text.trim().isNotEmpty) &&
      _yearOk;

  Future<void> _save() async {
    final v = Vehicle(
      id: widget.initial?.id ??
          'v${DateTime.now().millisecondsSinceEpoch}',
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: _year.text.trim(),
      plate: _plate.text.trim(),
      colorValue: _color,
      bodyType: _body,
      fuelType: _fuel,
    );
    await ref.read(garageProvider.notifier).saveVehicle(v);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this vehicle?'),
        content: const Text('It disappears from your garage. '
            'Offer history is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await ref.read(garageProvider.notifier).deleteVehicle(widget.initial!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add vehicle' : 'Edit vehicle'),
        actions: [
          if (widget.initial != null)
            IconButton(
              key: const ValueKey('editor-delete'),
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: VerdictColors.bad),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          // Live preview — re-renders on every setState (spec M6 §4.3).
          Container(
            padding: const EdgeInsets.symmetric(vertical: Gap.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FoxColors.inkSoft, FoxColors.ink],
              ),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            child: Center(
              child: VehicleArt(
                bodyType: _body,
                color: Color(_color),
                fuelType: _fuel,
                width: 220,
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('editor-make'),
                controller: _make,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Make', isDense: true),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('editor-model'),
                controller: _model,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Model', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Gap.md),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('editor-year'),
                controller: _year,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Year',
                  isDense: true,
                  errorText: _yearOk ? null : '4 digits',
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('editor-plate'),
                controller: _plate,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Plate', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Gap.lg),
          Text('COLOR', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final entry in DriverProfile.palette.entries)
                GestureDetector(
                  onTap: () => setState(() => _color = entry.key),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(entry.key),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == entry.key ? 3 : 1,
                        color: _color == entry.key
                            ? FoxColors.brandFox
                            : FoxColors.border,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('BODY', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final t in VehicleType.values)
                ChoiceChip(
                  label: Text(t.name),
                  selected: _body == t,
                  onSelected: (_) => setState(() => _body = t),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('FUEL', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final f in FuelType.values)
                ChoiceChip(
                  label: Text(switch (f) {
                    FuelType.gas => 'Gas',
                    FuelType.hybrid => 'Hybrid',
                    FuelType.ev => 'EV',
                  }),
                  selected: _fuel == f,
                  onSelected: (_) => setState(() => _fuel = f),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add route to `lib/router.dart`**

```dart
import 'package:go_router/go_router.dart';

import 'domain/garage.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/settings/vehicle_editor_screen.dart';
import 'ui/shell/root_shell.dart';

GoRouter createRouter({required bool showOnboarding}) => GoRouter(
  initialLocation: showOnboarding ? '/onboarding' : '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootShell()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/vehicle-editor',
      builder: (context, state) =>
          VehicleEditorScreen(initial: state.extra as Vehicle?),
    ),
  ],
);
```

(Splash route lands in Task 11; comment left in doc header there.)

- [ ] **Step 5: Garage section in `lib/ui/settings/settings_screen.dart`**

Replace the `'Driver profile'` section (`_SectionLabel('Driver profile')` + `_Card(child: _ProfileForm())`) and DELETE the whole `_ProfileForm`/`_ProfileFormState` classes. New section:

```dart
        const _SectionLabel('Driver'),
        const SizedBox(height: Gap.sm),
        const _Card(child: _DriverNameCard()),
        const SizedBox(height: Gap.lg),
        const _SectionLabel('Garage'),
        const SizedBox(height: Gap.sm),
        const _GarageList(),
```

New widgets (bottom of file):

```dart
/// Driver name — explicit save; check button appears while the draft differs
/// from the stored name (spec M6 §4.2 — no silent live-apply).
class _DriverNameCard extends ConsumerStatefulWidget {
  const _DriverNameCard();

  @override
  ConsumerState<_DriverNameCard> createState() => _DriverNameCardState();
}

class _DriverNameCardState extends ConsumerState<_DriverNameCard> {
  late final _name = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(driverNameProvider);
    if (!_seeded && saved.isNotEmpty) {
      _name.text = saved;
      _seeded = true;
    }
    final dirty = _name.text.trim() != saved.trim();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: 'Name', isDense: true),
          ),
        ),
        if (dirty) ...[
          const SizedBox(width: Gap.sm),
          IconButton(
            key: const ValueKey('save-name'),
            onPressed: () async {
              await ref
                  .read(driverNameProvider.notifier)
                  .setName(_name.text.trim());
              setState(() {});
            },
            icon: const Icon(Icons.check_circle_rounded,
                color: FoxColors.brandFox),
          ),
        ],
      ],
    );
  }
}

/// Vehicle list as premium mini car-cards + "+ Add vehicle" (spec M6 §4.2).
/// Tap = set active (instant, persisted). Edit icon = open editor.
class _GarageList extends ConsumerWidget {
  const _GarageList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    return Column(
      children: [
        for (final v in garage.vehicles) ...[
          _VehicleCard(
            vehicle: v,
            active: garage.active?.id == v.id,
            onTap: () => ref.read(garageProvider.notifier).setActive(v.id),
            onEdit: () => context.push('/vehicle-editor', extra: v),
          ),
          const SizedBox(height: Gap.sm),
        ],
        // "+ Add vehicle" card.
        InkWell(
          key: const ValueKey('add-vehicle'),
          borderRadius: BorderRadius.circular(Radii.cardSm),
          onTap: () => context.push('/vehicle-editor'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.cardSm),
              border: Border.all(color: FoxColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: FoxColors.brandFox, size: 20),
                SizedBox(width: Gap.sm),
                Text(
                  'Add vehicle',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.brandFox,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.active,
    required this.onTap,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.cardSm),
      onTap: onTap,
      onLongPress: onEdit,
      child: Container(
        padding: const EdgeInsets.all(Gap.sm + Gap.xs),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(
            color: active ? FoxColors.brandFox : FoxColors.borderSoft,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? Shadows.glowSoft : Shadows.soft,
        ),
        child: Row(
          children: [
            VehicleArt(
              bodyType: vehicle.bodyType,
              color: Color(vehicle.colorValue),
              fuelType: vehicle.fuelType,
              width: 72,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.title.isEmpty ? 'Unnamed vehicle' : vehicle.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FoxColors.textPrimary,
                    ),
                  ),
                  if (vehicle.plate.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: FoxColors.bgSurface2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: FoxColors.border),
                      ),
                      child: Text(
                        vehicle.plate,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: FoxColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded,
                  color: FoxColors.brandFox, size: 20),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  color: FoxColors.textSecondary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
```

Imports to add: `import 'package:go_router/go_router.dart';`, `import '../../domain/garage.dart';`, `import '../theme/vehicle_art.dart';`, `import 'garage_controller.dart';`. Remove `import 'profile_controller.dart';` and `import '../../domain/driver_profile.dart';` becomes unused if nothing else references it (VehicleType chips moved to editor) — remove if analyzer says so.

- [ ] **Step 6: Section icons + stagger + threshold-card tightening**

a) `_SectionLabel` gains an optional icon: `const _SectionLabel(this.text, {this.icon});` with `final IconData? icon;` — rendered before the text:

```dart
        if (icon != null) ...[
          Icon(icon, size: 14, color: FoxColors.textDisabled),
          const SizedBox(width: 6),
        ],
```

Assign per spec §6: Driver/Garage `Icons.person_outline_rounded`/`Icons.garage_outlined`, thresholds `Icons.tune_rounded`, pickup guard `Icons.near_me_outlined`, watched apps `Icons.apps_rounded`, pill size `Icons.circle_outlined`, parser health `Icons.monitor_heart_outlined`, logs `Icons.description_outlined`, history `Icons.history_rounded`, live preview `Icons.visibility_outlined`.

b) Stagger-slide sections on entry (≤8 animated, spec §6): wrap the ListView children. Add to `_SettingsScreenState`:

```dart
  Widget _staggered(int index, Widget child) {
    if (MediaQuery.of(context).disableAnimations || index > 7) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * index,
      curve: Motion.curve,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
```

Wrap each top-level section block (label+card pair) in `_staggered(i, Column(children: [...]))` — 10 sections, indices 0–9 (8+ render instantly by the guard).

c) Threshold cards narrower (spec §6): in `_ThresholdSlider`, value text `fontSize` 15→13.5 via `text.titleMedium?.copyWith(fontSize: 13.5, ...)`; `_Card` padding for the thresholds card stays global — instead reduce the `SizedBox(height: Gap.lg)` between band and first slider to `Gap.md`.

- [ ] **Step 7: Update `test/settings_screen_test.dart`**

Read the file first. Replace any pump/expect that references profile-form fields (`Name`, `Make`, live-apply assertions) with: name card seeds from `driverNameProvider`; check button appears on edit; garage list shows "Add vehicle". Keep threshold/watched-app/pill tests as-is (only styling changed). Provide `SharedPreferences.setMockInitialValues({})` in `setUp` if missing.

- [ ] **Step 8: Delete `lib/ui/settings/profile_controller.dart`**

```bash
grep -rn "profile_controller\|profileProvider" lib test
```
Expected: no hits outside the deleted file (Task 5 removed the profile_card usage; Step 5 removed settings usage). Then:

```bash
git rm lib/ui/settings/profile_controller.dart
```
`DriverProfile` domain class stays — migration (Task 2/3) and palette reference it.

- [ ] **Step 9: Run tests**

```bash
flutter test && flutter analyze
```
Expected: all PASS, 0 issues.

- [ ] **Step 10: Commit**

```bash
git add -A lib/ui/settings lib/router.dart test/vehicle_editor_test.dart test/settings_screen_test.dart
git commit -m "feat(m6): garage UI, vehicle editor route, settings dark restyle + stagger"
```

---

### Task 9: History — count bug fix + smart empty state + restyle

**Files:**
- Modify: `lib/ui/history/history_screen.dart`
- Test: `test/history_filter_test.dart` (new)

**Interfaces:**
- Consumes: `PlatformBadge` (Task 7), tokens, existing `offerLogProvider`.
- Produces: pure static helper on `HistoryScreen` for tests: `static String headerLabel(int filteredCount, HistoryRange range)` and public `enum HistoryRange { today, week, month, all }` (renamed from private `_Range` so tests can use it). Header shows FILTERED count + range name; empty-with-hidden-offers state shows "N offers outside these filters" + "Show all" button that resets range to All (spec M6 §5.1).

- [ ] **Step 1: Write the failing test** — `test/history_filter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/ui/history/history_screen.dart';

class _FixedLog extends OfferLog {
  _FixedLog(this._offers);
  final List<OfferSummary> _offers;
  @override
  List<OfferSummary> build() => _offers;
}

OfferSummary _offer(DateTime seenAt) => OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.good,
      payout: 20,
      totalKm: 10,
      seenAt: seenAt,
    );

Widget _app(List<OfferSummary> offers) => ProviderScope(
      overrides: [offerLogProvider.overrideWith(() => _FixedLog(offers))],
      child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
    );

void main() {
  test('headerLabel names the filtered range (spec M6 §5.1)', () {
    expect(HistoryScreen.headerLabel(0, HistoryRange.today), '0 today');
    expect(HistoryScreen.headerLabel(5, HistoryRange.today), '5 today');
    expect(HistoryScreen.headerLabel(3, HistoryRange.week), '3 in 7 days');
    expect(HistoryScreen.headerLabel(9, HistoryRange.month), '9 in 30 days');
    expect(HistoryScreen.headerLabel(22, HistoryRange.all), '22 all time');
  });

  testWidgets(
      'the 22-offers-empty-list bug: yesterday-only offers on Today filter '
      'show filtered count 0 + smart empty state', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final offers = List.generate(22, (_) => _offer(yesterday));
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();
    // Header: filtered count, NOT all-time 22.
    expect(find.text('0 today'), findsOneWidget);
    expect(find.text('22 offers'), findsNothing); // old broken header
    // Smart empty state names the hidden offers + offers a reset.
    expect(find.textContaining('22 offers outside these filters'),
        findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('22 all time'), findsOneWidget);
    expect(find.textContaining('outside these filters'), findsNothing);
  });

  testWidgets('truly empty log shows plain empty state, no Show all',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsNothing);
    expect(find.textContaining('No offers'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/history_filter_test.dart
```
Expected: FAIL — `HistoryRange`/`headerLabel` undefined.

- [ ] **Step 3: Fix + restyle `lib/ui/history/history_screen.dart`**

a) Rename `enum _Range` → `enum HistoryRange { today, week, month, all }` (top-level, public). Update all `_Range` references (`_range` field, `_RangeControl`, `_passes`).

b) Add to `HistoryScreen`:

```dart
  /// Header count label — FILTERED count, range named (spec M6 §5.1: the old
  /// header showed all.length while the list showed Today; post-midnight
  /// that read "22 offers" over an empty list).
  static String headerLabel(int filteredCount, HistoryRange range) =>
      switch (range) {
        HistoryRange.today => '$filteredCount today',
        HistoryRange.week => '$filteredCount in 7 days',
        HistoryRange.month => '$filteredCount in 30 days',
        HistoryRange.all => '$filteredCount all time',
      };
```

c) In `build`, header row `Text('${all.length} offers', ...)` →

```dart
            Text(
              HistoryScreen.headerLabel(filtered.length, _range),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FoxColors.textDisabled,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
```

d) Smart empty state — replace `if (filtered.isEmpty) const _Empty()` with:

```dart
        if (filtered.isEmpty)
          _Empty(
            hiddenCount: all.length,
            onShowAll: all.isEmpty
                ? null
                : () => setState(() {
                      _range = HistoryRange.all;
                      _apps
                        ..clear()
                        ..add(null);
                      _topOnly = false;
                    }),
          )
```

and rewrite `_Empty`:

```dart
/// Empty state. When offers exist but filters hide them, say so and offer a
/// one-tap reset (spec M6 §5.1) — "0 results" with 22 offers on disk reads
/// as data loss otherwise.
class _Empty extends StatelessWidget {
  const _Empty({required this.hiddenCount, this.onShowAll});

  final int hiddenCount;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final filtered = hiddenCount > 0 && onShowAll != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.search_off,
            size: 36,
            color: FoxColors.textDisabled,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            filtered
                ? '$hiddenCount offers outside these filters'
                : 'No offers yet — go live and drive.',
            style: const TextStyle(
                fontSize: 13, color: FoxColors.textDisabled),
          ),
          if (filtered) ...[
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: onShowAll,
              style:
                  TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              child: const Text('Show all',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
```

e) Restyle (spec M6 §5.2):
- `_OfferRow`: replace the 10px verdict dot with a left-edge glow strip — first child of the Row becomes:

```dart
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                    color: style.color.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
```

- `_OfferRow`: replace the 7px platform dot + label with `PlatformBadge(platform: offer.platform, size: 18)` + label (import `../theme/platform_badge.dart`; delete `_OfferRow._appColor`).
- `_AppChips._chip`: replace the color dot with `PlatformBadge(platform: app, size: 16, active: active)`; delete `_AppChips._appColor`.
- `_StatsCard` numbers: wrap each `_Stat.value` in the same `TweenAnimationBuilder<int>` count-up ONLY where value is an int count — simplest: leave `_Stat` text but wrap the OFFERS stat: skip — spec says "count-up numbers"; implement in `_Stat` for integer-parse-able values:

```dart
        // In _Stat.build, replace the value Text with:
        _isInt(value)
            ? TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: int.parse(value)),
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : Motion.count,
                curve: Motion.curve,
                builder: (context, v, _) => Text('$v', style: _valueStyle),
              )
            : Text(value, style: _valueStyle),
```

with statics on `_Stat`:

```dart
  static bool _isInt(String s) => int.tryParse(s) != null;
  static const _valueStyle = TextStyle(
    fontFamily: FoxFonts.display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: FoxColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
```

- Stagger rows on filter change (≤12 animated, spec §5.2): in `_grouped`, wrap each `_OfferRow` with index-aware entrance:

```dart
  Widget _row(OfferSummary o, int index) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced || index >= 12) return _OfferRow(offer: o);
    return TweenAnimationBuilder<double>(
      key: ValueKey('${o.seenAt.millisecondsSinceEpoch}-$_range-$_topOnly'),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * index,
      curve: Motion.curve,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: c),
      ),
      child: _OfferRow(offer: o),
    );
  }
```

Use `_row(o, i)` in both branches of `_grouped` (add an index counter).
- Dark token sweep already done in Task 1; verify no `FoxColors.ink` text remains in this file.

- [ ] **Step 4: Run tests**

```bash
flutter test test/history_filter_test.dart && flutter test && flutter analyze
```
Expected: all PASS, 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/history/history_screen.dart test/history_filter_test.dart
git commit -m "fix(m6): history header counts the filtered range + smart empty state; dark restyle"
```

---

### Task 10: Splash screen

**Files:**
- Create: `lib/ui/splash/splash_screen.dart`
- Modify: `lib/router.dart` (add `/splash`), `lib/main.dart` (initial location logic)
- Test: `test/splash_test.dart`

**Interfaces:**
- Consumes: `VehicleArt`-style CustomPaint (own painter — silhouette pass), tokens, go_router, `activeVehicleProvider` (body type for the car; sedan default).
- Produces: `SplashScreen` — `const SplashScreen({super.key})`; navigates `context.go('/')` when done. Route `/splash`. Cold-start-only: `createRouter` gains `showSplash` param; `main.dart` passes `showSplash: !showOnboarding` (onboarding flow keeps priority; splash never shows before onboarding).

- [ ] **Step 1: Write the failing test** — `test/splash_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/splash/splash_screen.dart';
import 'package:go_router/go_router.dart';

Widget _app({required Widget home}) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => home),
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('SHELL'))),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('splash navigates to shell after the sequence', (tester) async {
    await tester.pumpWidget(_app(home: const SplashScreen()));
    expect(find.text('FoxyCo'), findsOneWidget);
    expect(find.text('SHELL'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2400)); // 1.8s + crossfade
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('hard ceiling: navigates by 3s even if animation stalls',
      (tester) async {
    await tester.pumpWidget(_app(home: const SplashScreen()));
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
flutter test test/splash_test.dart
```
Expected: FAIL — `splash_screen.dart` not found.

- [ ] **Step 3: Implement `lib/ui/splash/splash_screen.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/driver_profile.dart';
import '../settings/garage_controller.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_art.dart';

/// Animated launch splash (spec M6 §2). One AnimationController, staged
/// Intervals: wordmark fade (0–0.25), car drive-in + headlight sweep
/// (0.15–0.75), road shimmer throughout, hold, then go('/'). ~1.8s.
/// Reduced motion: static logo, 0.5s. Hard 3s ceiling Timer force-navigates
/// even if the controller stalls (spec M6 §10) — splash never traps.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _ceiling;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Ceiling armed before anything can fail.
    _ceiling = Timer(const Duration(seconds: 3), _go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reduced = MediaQuery.of(context).disableAnimations;
      if (reduced) {
        Timer(const Duration(milliseconds: 500), _go);
      } else {
        _c.forward().whenComplete(_go);
      }
    });
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _ceiling?.cancel();
    context.go('/');
  }

  @override
  void dispose() {
    _ceiling?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final bodyType =
        ref.watch(activeVehicleProvider)?.bodyType ?? VehicleType.sedan;

    return Scaffold(
      backgroundColor: FoxColors.bgBase,
      body: reduced
          ? const Center(child: _Wordmark(opacity: 1))
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final wordmark = const Interval(0.0, 0.25, curve: Curves.easeOut)
                    .transform(_c.value);
                final drive = const Interval(0.15, 0.75, curve: Curves.easeOutCubic)
                    .transform(_c.value);
                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.25),
                      child: _Wordmark(opacity: wordmark),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: CustomPaint(
                        size: const Size(320, 120),
                        painter: _SplashScenePainter(
                          progress: drive,
                          shimmer: _c.value,
                          bodyType: bodyType,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: const Text(
        'FoxyCo',
        style: TextStyle(
          fontFamily: FoxFonts.display,
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: FoxColors.cream,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

/// Car silhouette drives in from the left with a headlight beam; a road line
/// shimmers underneath. Silhouette pass reuses VehicleArtPainter at full
/// black-ish tint (art detail reads as shape at this size).
class _SplashScenePainter extends CustomPainter {
  const _SplashScenePainter({
    required this.progress,
    required this.shimmer,
    required this.bodyType,
  });

  final double progress; // 0..1 drive-in
  final double shimmer; // 0..1 whole-sequence t
  final VehicleType bodyType;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Road line with a moving shimmer highlight.
    final roadY = 0.88 * h;
    canvas.drawLine(
      Offset(0.05 * w, roadY),
      Offset(0.95 * w, roadY),
      Paint()
        ..color = FoxColors.cream.withValues(alpha: 0.12)
        ..strokeWidth = 2,
    );
    final shimmerX = (0.05 + 0.9 * shimmer) * w;
    canvas.drawLine(
      Offset(shimmerX - 0.08 * w, roadY),
      Offset(shimmerX + 0.08 * w, roadY),
      Paint()
        ..color = FoxColors.cream.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Car drives in: x from -carW to center.
    const carW = 150.0;
    final carX = -carW + (0.5 * w - carW / 2 + carW) * progress;
    canvas.save();
    canvas.translate(carX, roadY - 0.52 * carW * 0.48 - 8);
    final painter = VehicleArtPainter(
      bodyType: bodyType,
      color: const Color(0xFF2A3A31), // silhouette tint, not profile color
      fuelType: FuelType.gas,
    );
    painter.paint(canvas, const Size(carW, carW * 0.48));
    canvas.restore();

    // Headlight beam sweep — wedge from the car nose, fades late.
    if (progress > 0.15) {
      final noseX = carX + carW * 0.95;
      final noseY = roadY - 18;
      final beamAlpha = (0.30 * (1 - (progress - 0.6).clamp(0, 0.4) / 0.4));
      final beam = Path()
        ..moveTo(noseX, noseY)
        ..lineTo(noseX + 0.35 * w, noseY - 14)
        ..lineTo(noseX + 0.35 * w, noseY + 18)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFFE9B8).withValues(alpha: beamAlpha),
              const Color(0x00FFE9B8),
            ],
          ).createShader(
              Rect.fromLTWH(noseX, noseY - 14, 0.35 * w, 32)),
      );
    }
  }

  @override
  bool shouldRepaint(_SplashScenePainter old) =>
      old.progress != progress ||
      old.shimmer != shimmer ||
      old.bodyType != bodyType;
}
```

Import fix: `_SplashScenePainter` needs `import '../../domain/garage.dart';` for `FuelType` (add it).

- [ ] **Step 4: Wire the route + cold-start logic**

`lib/router.dart` — add param + route:

```dart
GoRouter createRouter({
  required bool showOnboarding,
  bool showSplash = false,
}) => GoRouter(
  initialLocation: showOnboarding
      ? '/onboarding'
      : showSplash
          ? '/splash'
          : '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootShell()),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // ... existing onboarding + vehicle-editor routes unchanged
  ],
);
```

Import: `import 'ui/splash/splash_screen.dart';`.

`lib/main.dart` — cold start only (router built once per process, so this is inherently once-per-cold-start; resume never rebuilds it):

```dart
  late final _router = createRouter(
    showOnboarding: widget.showOnboarding,
    showSplash: !widget.showOnboarding,
  );
```

Shell providers already warm up behind the splash — the `addPostFrameCallback` in `_FoxyCoAppState.initState` reads them at first frame regardless of route (spec §2 "never blocks").

- [ ] **Step 5: Run tests**

```bash
flutter test test/splash_test.dart && flutter test && flutter analyze
```
Expected: all PASS. `widget_test.dart` may pump the app root and now land on `/splash` — if it asserts Home content, pass `showSplash: false` there or `pumpAndSettle(const Duration(seconds: 4))`. 0 analyze issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/splash lib/router.dart lib/main.dart test/splash_test.dart
git commit -m "feat(m6): animated launch splash with 3s hard ceiling"
```

---

### Task 11: Full sweep — analyze, tests, manual test rows, completion doc

**Files:**
- Modify: `docs/MANUAL_TESTS.md` (append M6 rows)
- Create: `.claude/completions/2026-07-XX-m6-showroom.md` (date of execution day)

- [ ] **Step 1: Full validation**

```bash
flutter analyze && flutter test
```
Expected: 0 issues, all tests pass. Fix anything that fails before proceeding.

- [ ] **Step 2: Inline-color audit**

```bash
grep -rn "Color(0x" lib/ui --include="*.dart" | grep -v "theme/" | grep -v "overlay/"
```
Expected: only justified exceptions with a comment (splash silhouette tint is one). Fix stragglers.

- [ ] **Step 3: Overlay-untouched audit**

```bash
git diff --stat $(git log --oneline | grep -B999 "feat(m6)" | tail -1 | cut -d' ' -f1)~1 -- lib/ui/overlay lib/parser lib/services/accessibility
```
Simpler: `git log --oneline -- lib/ui/overlay lib/parser lib/services/accessibility` — no m6 commits may appear. If any do, STOP and revert those hunks.

- [ ] **Step 4: Append M6 rows to `docs/MANUAL_TESTS.md`**

Read the file, match its row format, append (adjust wording to the file's style):

```markdown
## M6 — Showroom (dark UI, garage, slide-to-live, splash)

| # | Check | Steps | Expect |
|---|-------|-------|--------|
| M6.1 | Splash timing | Cold-start app | Dark splash, wordmark fade + car drive-in ≈1.8s, crossfade to Home; never longer than 3s |
| M6.2 | Splash reduced motion | Enable "Remove animations" in OS a11y, cold start | Static logo ~0.5s, no car sweep |
| M6.3 | Slide-to-live commit | Drag bolt thumb ≥85% right | Medium haptic, control morphs to Live bar with pulsing dot |
| M6.4 | Slide spring-back | Drag thumb ~40% and release | Springs back with overshoot, light haptic, stays stopped |
| M6.5 | Slide-to-stop | While live, drag thumb back left | Stops watching; bar morphs back to slide track |
| M6.6 | Slider a11y | TalkBack on, focus control | Announced as "Go live"/"Stop" button; double-tap activates |
| M6.7 | Garage migration | Install over M5 build with a saved profile | Vehicle appears in Garage as active; name preserved; no data loss |
| M6.8 | Garage flow | Add 2nd vehicle, set active, edit, delete active | Active switches on tap; delete falls back to remaining; hero card follows |
| M6.9 | Editor discard | Edit vehicle, change color, press Cancel | No change persisted anywhere (hero + garage unchanged) |
| M6.10 | Greeting bands | Set device clock 23:30, open Home | "Late shift, <name>" (not "Good evening") |
| M6.11 | History count | With yesterday-only offers, open History (Today) | Header "0 today"; body "N offers outside these filters" + Show all resets |
| M6.12 | Dark sunlight contrast | Outdoors/bright light | Verdict colors + text legible on dark cards |
| M6.13 | OV.1/OV.6 regression | Run overlay bubble + pill flows from M3/M5 rows | Unchanged behavior (overlay untouched in M6) |
```

- [ ] **Step 5: Completion doc** — `.claude/completions/<date>-m6-showroom.md`: files changed, behavior changed, tests run, follow-ups (licensed PNG art fallback if device check says painters aren't premium enough — spec §7).

- [ ] **Step 6: Final commit**

```bash
git add docs/MANUAL_TESTS.md .claude/completions
git commit -m "test(m6): manual test rows + completion doc"
```

---

## Self-Review Notes (already applied)

- Spec coverage: §1→T1, §2→T10, §3.1→T5, §3.2→T6, §3.3/3.4→T7, §4→T2/T3/T8, §5→T9, §6→T8, §7→T4, §8→tokens in T1 + per-site checks, §9 file map matches tasks, §10→T3 (fail-soft/migration) + T10 (ceiling) + T8 (validation), §11→each task's tests + T11, §12 order preserved (T1=tokens, T2/3=garage logic, T4=art, T5–7=home, T8=garage UI+settings, T9=history, T10=splash, T11=sweep). Settings restyle folded into T8 (same file, one reviewer gate).
- Type consistency: `garageProvider`/`activeVehicleProvider`/`driverNameProvider` names identical in T3/T5/T8/T10; `VehicleArt(bodyType:, color:, fuelType:, width:)` identical T4/T5/T8/T10; `SlideToLive.commitFraction` only referenced in T6; `HistoryRange` public rename contained in T9.
- Spec's "editor full-screen new route" honored (T8 `/vehicle-editor` via go_router, matching onboarding pattern) — note logs_screen uses `Navigator.push`; go_router chosen because spec §9 says "router.dart — splash route + editor route".
- Deviation from spec §9: "profile_controller shrinks to name-only or folds into garage controller" → folded (DriverNameController in garage_controller.dart), profile_controller.dart deleted in T8. Implementation's choice per spec.
