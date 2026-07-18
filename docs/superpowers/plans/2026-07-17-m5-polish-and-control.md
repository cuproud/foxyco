# M5 — Polish & Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live pill size, persistent file logs, driver profile with hero card, manual monitoring start.

**Architecture:** Four independent features on the existing Riverpod + SharedPreferences stack. Overlay isolate reads `payload.size` and resizes its window; a new `FoxLog` service appends buffered lines to a rotated file; `DriverProfile` follows the `FoxSettings` persistence pattern; `WatchStatus.stopped` gates the whole pipeline behind a Start button.

**Tech Stack:** Flutter, Riverpod (`Notifier`), SharedPreferences, `flutter_overlay_window` (vendored), `path_provider` (NEW dep, approved in spec).

## Global Constraints

- Overlay window width MUST stay under 360dp (native X-clamp; see `overlay_entry.dart` `_pillBox` comment). Boxes: small 300×72, medium 324×84, large 348×100 dp.
- `path_provider` is the ONLY new dependency. No `share_plus` (clipboard export instead).
- Log file: `logs/foxyco.log` in app documents dir, 1 MB rotation to `foxyco.log.1`, two files max.
- Profile prefs key: `foxyco.profile.v1`.
- Never persist a running watch state — app always boots `stopped` (or `blocked`).
- Fail-soft everywhere: logger/profile I/O errors are swallowed, never crash the pipeline.
- Respect `MediaQuery.disableAnimations` on hero card animation.
- After each task: `flutter analyze` clean, `flutter test` green.
- Uber detection investigation is OUT OF SCOPE. Nothing here touches parsing logic.

---

### Task 1: Pill size — live effect (overlay + settings preview)

**Files:**
- Modify: `lib/ui/overlay/overlay_entry.dart` (window boxes + render size)
- Modify: `lib/ui/settings/settings_screen.dart` (live preview under selector)
- Test: `test/settings_screen_test.dart` (add preview test), `test/overlay_payload_test.dart` (already covers size round-trip — no change)

**Interfaces:**
- Consumes: `OverlayPayload.size` (exists), `VerdictPill(payload:, size:)` (exists — passing `null` size means "use payload.size" per its doc).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write failing widget test for the settings preview**

Append to `test/settings_screen_test.dart` (match its existing `pumpWidget(ProviderScope(child: MaterialApp(home: SettingsScreen())))` style):

```dart
testWidgets('pill size selector shows live VerdictPill preview', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: SettingsScreen())),
  );
  await tester.pumpAndSettle();

  // Preview pill is rendered on the settings screen.
  expect(find.byType(VerdictPill), findsOneWidget);

  // Selecting Large re-renders the preview at the large size.
  final smallSize = tester.getSize(find.byType(VerdictPill));
  await tester.tap(find.text('Large'));
  await tester.pumpAndSettle();
  final largeSize = tester.getSize(find.byType(VerdictPill));
  expect(largeSize.height, greaterThan(smallSize.height));
});
```

Add import: `import 'package:foxyco/ui/overlay/verdict_pill.dart';`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_screen_test.dart -r expanded`
Expected: FAIL — `findsOneWidget` finds zero `VerdictPill`.

- [ ] **Step 3: Add the preview to the settings screen**

In `lib/ui/settings/settings_screen.dart`, directly after the Pill size `_ChoiceRow` card (after the `_Card` closing that holds it, around line 195), insert:

```dart
const SizedBox(height: Gap.sm + Gap.xs),
// Live preview — sample payload at the selected size, so the change is
// visible instantly without waiting for a real offer.
Center(
  child: VerdictPill(
    payload: const OverlayPayload(
      verdict: Verdict.good,
      totalKm: 8.4,
      payout: 12,
      totalMinutes: 24,
    ),
    size: settings.pillSize,
  ),
),
```

Adjust imports: change `show PillSize` to `show OverlayPayload, PillSize` on the `overlay_payload.dart` import; add `import '../../domain/verdict.dart';` and `import '../overlay/verdict_pill.dart';`.

- [ ] **Step 4: Make the overlay isolate honor payload.size**

In `lib/ui/overlay/overlay_entry.dart`:

Replace:

```dart
  static const _pillBox = (w: 300, h: 72);
```

with (keep the existing X-clamp comment above it):

```dart
  // Per-size boxes (spec M5 §1). Width MUST stay <360dp — see comment above.
  static ({int w, int h}) _pillBoxFor(PillSize size) => switch (size) {
    PillSize.small => (w: 300, h: 72),
    PillSize.medium => (w: 324, h: 84),
    PillSize.large => (w: 348, h: 100),
  };
```

In `_onData`, replace `_resize(_pillBox);` with:

```dart
      final payload = OverlayPayload.fromMap(data);
      setState(() => _payload = payload);
      _resize(_pillBoxFor(payload.size)); // window fits the chosen size
```

(deleting the old `setState(() => _payload = OverlayPayload.fromMap(data));` line above it).

In `build`, replace `VerdictPill(payload: payload, size: PillSize.small)` with `VerdictPill(payload: payload)` — null size falls through to `payload.size`.

Add `PillSize` to imports if not already visible via `overlay_payload.dart` import (it is — same file).

- [ ] **Step 5: Run tests**

Run: `flutter test && flutter analyze`
Expected: all pass, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/overlay/overlay_entry.dart lib/ui/settings/settings_screen.dart test/settings_screen_test.dart
git commit -m "feat(M5): pill size takes effect — overlay renders payload.size, settings live preview"
```

---

### Task 2: FoxLog service (file logging + rotation)

**Files:**
- Create: `lib/services/fox_log.dart`
- Modify: `pubspec.yaml` (add `path_provider`)
- Test: `test/fox_log_test.dart`

**Interfaces:**
- Produces (later tasks depend on these exact names):
  - `class FoxLog` with `void log(String tag, String message)`, `Future<String> tail({int maxChars = 64 * 1024})`, `Future<void> clear()`, `Future<void> flush()`.
  - `final foxLogProvider = Provider<FoxLog>(...)`.
  - Constructor `FoxLog({Future<Directory?> Function()? dirResolver, int maxBytes = 1024 * 1024})` — tests inject a temp dir; production default resolves via `path_provider`, returns null off-device (no-op logger).

- [ ] **Step 1: Add path_provider**

Run: `flutter pub add path_provider`
Expected: `pubspec.yaml` gains `path_provider: ^2.x`, `flutter pub get` succeeds.

- [ ] **Step 2: Write failing tests**

Create `test/fox_log_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/fox_log.dart';

void main() {
  late Directory tmp;
  late FoxLog log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foxlog');
    log = FoxLog(dirResolver: () async => tmp);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  File logFile() => File('${tmp.path}/logs/foxyco.log');
  File rolled() => File('${tmp.path}/logs/foxyco.log.1');

  test('log appends a tagged timestamped line after flush', () async {
    log.log('watch', 'hello');
    await log.flush();
    final content = logFile().readAsStringSync();
    expect(content, contains('[watch] hello'));
    // ISO-ish timestamp leads the line.
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(content), isTrue);
  });

  test('rotation: exceeding maxBytes rolls to .1 and truncates current', () async {
    final small = FoxLog(dirResolver: () async => tmp, maxBytes: 200);
    for (var i = 0; i < 20; i++) {
      small.log('parse', 'x' * 40);
      await small.flush();
    }
    expect(rolled().existsSync(), isTrue);
    expect(logFile().lengthSync(), lessThanOrEqualTo(300));
  });

  test('tail returns end of file', () async {
    log.log('overlay', 'first');
    log.log('overlay', 'last');
    await log.flush();
    final t = await log.tail();
    expect(t, contains('first'));
    expect(t, contains('last'));
  });

  test('clear removes both files', () async {
    log.log('status', 'x');
    await log.flush();
    await log.clear();
    expect(logFile().existsSync(), isFalse);
    expect(rolled().existsSync(), isFalse);
  });

  test('fail-soft: null dir resolver is a silent no-op', () async {
    final noop = FoxLog(dirResolver: () async => null);
    noop.log('error', 'nowhere');
    await noop.flush();
    await noop.clear();
    expect(await noop.tail(), isEmpty); // no throw
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/fox_log_test.dart`
Expected: FAIL — `fox_log.dart` doesn't exist.

- [ ] **Step 4: Implement FoxLog**

Create `lib/services/fox_log.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent, buffered, fail-soft file logger (spec M5 §2).
///
/// Lines: `2026-07-16T21:04:11.123 [tag] message`. Appends go to an in-memory
/// queue and hit disk on a short timer — hot a11y paths never block on I/O.
/// At [maxBytes] the file rolls to `foxyco.log.1` (previous `.1` deleted);
/// two files max. Every I/O error is swallowed: a logger must never crash the
/// pipeline. Off-device (tests without an injected dir) it is a silent no-op.
class FoxLog {
  FoxLog({Future<Directory?> Function()? dirResolver, this.maxBytes = 1024 * 1024})
      : _dirResolver = dirResolver ?? _defaultDir;

  final Future<Directory?> Function() _dirResolver;
  final int maxBytes;

  final List<String> _buffer = [];
  Timer? _flushTimer;

  static Future<Directory?> _defaultDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null; // plugin channel missing (tests) → no-op logger
    }
  }

  Future<File?> _file() async {
    final dir = await _dirResolver();
    if (dir == null) return null;
    final logs = Directory('${dir.path}/logs');
    if (!logs.existsSync()) logs.createSync(recursive: true);
    return File('${logs.path}/foxyco.log');
  }

  /// Queue a line; flushed to disk within ~2s (or on [flush]).
  void log(String tag, String message) {
    _buffer.add('${DateTime.now().toIso8601String()} [$tag] $message');
    _flushTimer ??= Timer(const Duration(seconds: 2), () {
      _flushTimer = null;
      flush();
    });
  }

  /// Write the buffer out now. Safe to call anytime; fail-soft.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final lines = List.of(_buffer);
    _buffer.clear();
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString('${lines.join('\n')}\n',
          mode: FileMode.append, flush: true);
      if (file.lengthSync() > maxBytes) _rotate(file);
    } catch (_) {/* fail-soft */}
  }

  void _rotate(File file) {
    try {
      final old = File('${file.path}.1');
      if (old.existsSync()) old.deleteSync();
      file.renameSync(old.path);
    } catch (_) {/* fail-soft */}
  }

  /// Last [maxChars] of the current file (viewer shows the tail).
  Future<String> tail({int maxChars = 64 * 1024}) async {
    try {
      await flush();
      final file = await _file();
      if (file == null || !file.existsSync()) return '';
      final content = file.readAsStringSync();
      return content.length <= maxChars
          ? content
          : content.substring(content.length - maxChars);
    } catch (_) {
      return '';
    }
  }

  /// Truncate both files (Settings → Clear).
  Future<void> clear() async {
    try {
      _buffer.clear();
      final file = await _file();
      if (file == null) return;
      if (file.existsSync()) file.deleteSync();
      final old = File('${file.path}.1');
      if (old.existsSync()) old.deleteSync();
    } catch (_) {/* fail-soft */}
  }
}

final foxLogProvider = Provider<FoxLog>((ref) => FoxLog());
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/fox_log_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 6: Wire log calls into the pipeline**

Alongside (not replacing) existing `debugPrint`s:

`lib/services/accessibility/offer_watcher.dart` — add `import '../fox_log.dart';`, then:
- In `_onRead` after the kDebugMode trace block: `ref.read(foxLogProvider).log('watch', 'read pkg=${read.packageName} nodes=${read.texts.length}');`
- After a successful parse (next to `recordParse`): `ref.read(foxLogProvider).log('parse', '${offer.platform.label} \$${offer.payout} ${offer.totalKm}km → $verdict');`
- In the card-miss branch (next to `recordCardMiss`): `ref.read(foxLogProvider).log('parse', 'MISS card-like frame ${parser.platform.label}');`
- In `_clearNow` after `clearOffer()`: `ref.read(foxLogProvider).log('overlay', 'pill cleared — offer left screen');`
- In the `build()` `onError` handler: `ref.read(foxLogProvider).log('error', 'read stream: $e');`

`lib/ui/overlay/overlay_controller.dart` — add `import '../../services/fox_log.dart';`, then in `showFromOffer` before `return _service.showOffer(...)`: `ref.read(foxLogProvider).log('overlay', 'show ${offer.platform.label} \$${offer.payout} $verdict');`

`lib/ui/home/dashboard_controller.dart` — add `import '../../services/fox_log.dart';`, then wherever `state = _with(status: ...)` changes status (togglePause, stopWatching, refreshPermissions): `ref.read(foxLogProvider).log('status', 'watch → ${next.name}');` (use the local status variable in each method).

- [ ] **Step 7: Run full suite**

Run: `flutter test && flutter analyze`
Expected: green, clean. (Off-device the provider's default FoxLog no-ops — existing tests unaffected.)

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/fox_log.dart test/fox_log_test.dart lib/services/accessibility/offer_watcher.dart lib/ui/overlay/overlay_controller.dart lib/ui/home/dashboard_controller.dart
git commit -m "feat(M5): FoxLog persistent file logs — buffered, rotated, fail-soft, wired into pipeline"
```

---

### Task 3: Logs viewer screen (Settings → Logs)

**Files:**
- Create: `lib/ui/settings/logs_screen.dart`
- Modify: `lib/ui/settings/settings_screen.dart` (Logs tile)
- Test: `test/logs_screen_test.dart`

**Interfaces:**
- Consumes: `foxLogProvider` → `FoxLog.tail()`, `FoxLog.clear()` (Task 2).
- Produces: `class LogsScreen extends ConsumerStatefulWidget` (route pushed via `MaterialPageRoute` from settings — no router change).

- [ ] **Step 1: Write failing widget test**

Create `test/logs_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/fox_log.dart';
import 'package:foxyco/ui/settings/logs_screen.dart';

void main() {
  late Directory tmp;
  late FoxLog log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foxlogui');
    log = FoxLog(dirResolver: () async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget app() => ProviderScope(
        overrides: [foxLogProvider.overrideWithValue(log)],
        child: const MaterialApp(home: LogsScreen()),
      );

  testWidgets('shows log tail', (tester) async {
    log.log('watch', 'hello-line');
    await log.flush();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('hello-line'), findsOneWidget);
  });

  testWidgets('clear empties the view after confirm', (tester) async {
    log.log('watch', 'doomed');
    await log.flush();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear')); // confirm dialog action
    await tester.pumpAndSettle();
    expect(find.textContaining('doomed'), findsNothing);
    expect(find.textContaining('No logs yet'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/logs_screen_test.dart`
Expected: FAIL — `logs_screen.dart` doesn't exist.

- [ ] **Step 3: Implement LogsScreen**

Create `lib/ui/settings/logs_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fox_log.dart';
import '../theme/tokens.dart';

/// Scrollable tail of the persistent log (spec M5 §2). Newest at bottom;
/// copy-to-clipboard export (no share dep) and a confirm-gated Clear.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String _tail = '';
  bool _loaded = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final tail = await ref.read(foxLogProvider).tail();
    if (!mounted) return;
    setState(() {
      _tail = tail;
      _loaded = true;
    });
    // Newest lines live at the bottom — jump there after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _tail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('Deletes both log files. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(foxLogProvider).clear();
    await _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy to clipboard',
            onPressed: _tail.isEmpty ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear logs',
            onPressed: _clear,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _tail.isEmpty
              ? const Center(child: Text('No logs yet'))
              : SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(Gap.md),
                  child: SelectableText(
                    _tail,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                  ),
                ),
    );
  }
}
```

- [ ] **Step 4: Add the Logs tile to settings**

In `lib/ui/settings/settings_screen.dart`, after the Parser health section's card, add:

```dart
const SizedBox(height: Gap.lg),
const _SectionLabel('Logs'),
const SizedBox(height: Gap.sm + Gap.xs),
_Card(
  child: ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('View logs'),
    subtitle: const Text('Persistent debug log — survives restarts'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LogsScreen()),
    ),
  ),
),
```

Add `import 'logs_screen.dart';`. Match surrounding `_Card`/`_SectionLabel` usage exactly (they exist in this file).

- [ ] **Step 5: Run tests**

Run: `flutter test && flutter analyze`
Expected: green, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/logs_screen.dart lib/ui/settings/settings_screen.dart test/logs_screen_test.dart
git commit -m "feat(M5): Settings → Logs viewer — tail view, clipboard export, confirm-gated clear"
```

---

### Task 4: DriverProfile model + persistence

**Files:**
- Create: `lib/domain/driver_profile.dart`
- Create: `lib/ui/settings/profile_controller.dart`
- Test: `test/driver_profile_test.dart`

**Interfaces:**
- Produces (Tasks 5–6 depend on these exact names):
  - `enum VehicleType { sedan, suv, hatchback, pickup, van, motorbike }`
  - `class DriverProfile` fields: `String name`, `String vehicleMake`, `String vehicleModel`, `String vehicleYear`, `String licensePlate`, `int vehicleColor` (ARGB int — pure Dart domain, no Flutter `Color`), `VehicleType vehicleType`. Methods: `copyWith(...)` (all named optional), `toJson()`, `factory DriverProfile.fromJson(Map<String, dynamic>)`, `static const empty`, `bool get hasName`, `String get vehicleLine` ("Red 2022 Toyota Camry · ABC-123", skipping empty parts; color name from `colorName`), `static const palette = <int, String>{...}` (10 swatches → names).
  - `final profileProvider = NotifierProvider<ProfileController, DriverProfile>(...)` with setters `setName(String)`, `setMake(String)`, `setModel(String)`, `setYear(String)`, `setPlate(String)`, `setColor(int)`, `setType(VehicleType)`.

- [ ] **Step 1: Write failing tests**

Create `test/driver_profile_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';

void main() {
  test('empty profile has no name and empty vehicle line', () {
    expect(DriverProfile.empty.hasName, isFalse);
    expect(DriverProfile.empty.vehicleLine, isEmpty);
  });

  test('json round-trip preserves every field', () {
    final p = DriverProfile.empty.copyWith(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleModel: 'Camry',
      vehicleYear: '2022',
      licensePlate: 'ABC-123',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.suv,
    );
    final back = DriverProfile.fromJson(p.toJson());
    expect(back.name, 'Vamsi');
    expect(back.vehicleMake, 'Toyota');
    expect(back.vehicleModel, 'Camry');
    expect(back.vehicleYear, '2022');
    expect(back.licensePlate, 'ABC-123');
    expect(back.vehicleColor, 0xFFC62828);
    expect(back.vehicleType, VehicleType.suv);
  });

  test('fromJson tolerates missing/garbage fields', () {
    final p = DriverProfile.fromJson(const {'vehicleType': 'spaceship'});
    expect(p.name, isEmpty);
    expect(p.vehicleType, VehicleType.sedan);
  });

  test('vehicleLine skips empty parts cleanly', () {
    expect(
      DriverProfile.empty
          .copyWith(
            vehicleMake: 'Toyota',
            vehicleColor: 0xFFC62828,
          )
          .vehicleLine,
      'Red Toyota',
    );
    expect(
      DriverProfile.empty
          .copyWith(vehicleMake: 'Honda', licensePlate: 'XYZ')
          .vehicleLine,
      contains('· XYZ'),
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/driver_profile_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement DriverProfile**

Create `lib/domain/driver_profile.dart`:

```dart
/// Vehicle body style — picks the hero-card silhouette (spec M5 §3).
enum VehicleType { sedan, suv, hatchback, pickup, van, motorbike }

/// The driver's profile (spec M5 §3). Pure Dart — color is an ARGB int so
/// `domain/` stays Flutter-free; UI wraps it in `Color(...)`.
///
/// All fields optional; "complete enough for the hero card" == non-empty name.
/// [toJson]/[fromJson] are the whole storage format (one SharedPreferences
/// string, key `foxyco.profile.v1`) — same discipline as [FoxSettings].
class DriverProfile {
  final String name;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleYear;
  final String licensePlate;
  final int vehicleColor; // ARGB
  final VehicleType vehicleType;

  const DriverProfile({
    this.name = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleYear = '',
    this.licensePlate = '',
    this.vehicleColor = 0xFFF5F5F5, // white
    this.vehicleType = VehicleType.sedan,
  });

  static const empty = DriverProfile();

  /// Fixed swatch row (spec): value → display name used in [vehicleLine].
  static const palette = <int, String>{
    0xFFF5F5F5: 'White',
    0xFF212121: 'Black',
    0xFFB0BEC5: 'Silver',
    0xFF757575: 'Gray',
    0xFFC62828: 'Red',
    0xFF1565C0: 'Blue',
    0xFF2E7D32: 'Green',
    0xFFF9A825: 'Gold',
    0xFFEF6C00: 'Orange',
    0xFF5D4037: 'Brown',
  };

  bool get hasName => name.trim().isNotEmpty;

  String get colorName => palette[vehicleColor] ?? '';

  /// "Red 2022 Toyota Camry · ABC-123" — empty parts skipped cleanly.
  String get vehicleLine {
    final desc = [colorName, vehicleYear, vehicleMake, vehicleModel]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    if (desc.isEmpty && licensePlate.trim().isEmpty) return '';
    if (licensePlate.trim().isEmpty) return desc;
    if (desc.isEmpty) return licensePlate;
    return '$desc · $licensePlate';
  }

  DriverProfile copyWith({
    String? name,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleYear,
    String? licensePlate,
    int? vehicleColor,
    VehicleType? vehicleType,
  }) => DriverProfile(
    name: name ?? this.name,
    vehicleMake: vehicleMake ?? this.vehicleMake,
    vehicleModel: vehicleModel ?? this.vehicleModel,
    vehicleYear: vehicleYear ?? this.vehicleYear,
    licensePlate: licensePlate ?? this.licensePlate,
    vehicleColor: vehicleColor ?? this.vehicleColor,
    vehicleType: vehicleType ?? this.vehicleType,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'make': vehicleMake,
    'model': vehicleModel,
    'year': vehicleYear,
    'plate': licensePlate,
    'color': vehicleColor,
    'type': vehicleType.name,
  };

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
    name: j['name'] as String? ?? '',
    vehicleMake: j['make'] as String? ?? '',
    vehicleModel: j['model'] as String? ?? '',
    vehicleYear: j['year'] as String? ?? '',
    licensePlate: j['plate'] as String? ?? '',
    vehicleColor: (j['color'] as num?)?.toInt() ?? 0xFFF5F5F5,
    vehicleType: VehicleType.values
        .where((t) => t.name == j['type'])
        .firstOrNull ??
        VehicleType.sedan,
  );
}
```

- [ ] **Step 4: Implement ProfileController**

Create `lib/ui/settings/profile_controller.dart` (mirrors `SettingsController` exactly):

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/driver_profile.dart';

/// Holds the driver profile, persisted as one SharedPreferences JSON blob
/// (`foxyco.profile.v1`) — same live-apply pattern as [SettingsController]:
/// every setter saves immediately, no explicit save button.
class ProfileController extends Notifier<DriverProfile> {
  static const _prefsKey = 'foxyco.profile.v1';

  @override
  DriverProfile build() {
    _load();
    return DriverProfile.empty;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = DriverProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo profile load skipped: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo profile save skipped: $e');
    }
  }

  void _set(DriverProfile next) {
    state = next;
    _save();
  }

  void setName(String v) => _set(state.copyWith(name: v));
  void setMake(String v) => _set(state.copyWith(vehicleMake: v));
  void setModel(String v) => _set(state.copyWith(vehicleModel: v));
  void setYear(String v) => _set(state.copyWith(vehicleYear: v));
  void setPlate(String v) => _set(state.copyWith(licensePlate: v));
  void setColor(int v) => _set(state.copyWith(vehicleColor: v));
  void setType(VehicleType v) => _set(state.copyWith(vehicleType: v));
}

final profileProvider = NotifierProvider<ProfileController, DriverProfile>(
  ProfileController.new,
);
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/driver_profile_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/driver_profile.dart lib/ui/settings/profile_controller.dart test/driver_profile_test.dart
git commit -m "feat(M5): DriverProfile model + persisted controller (foxyco.profile.v1)"
```

---

### Task 5: Profile form in Settings

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart` (Profile section at top)
- Test: `test/settings_screen_test.dart`

**Interfaces:**
- Consumes: `profileProvider` setters, `DriverProfile.palette`, `VehicleType` (Task 4).

- [ ] **Step 1: Write failing widget test**

Append to `test/settings_screen_test.dart`:

```dart
testWidgets('profile form saves name live', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: SettingsScreen())),
  );
  await tester.pumpAndSettle();

  final nameField = find.widgetWithText(TextField, 'Name');
  expect(nameField, findsOneWidget);
  await tester.enterText(nameField, 'Vamsi');
  await tester.pumpAndSettle();

  final ctx = tester.element(find.byType(SettingsScreen));
  final container = ProviderScope.containerOf(ctx);
  expect(container.read(profileProvider).name, 'Vamsi');
});
```

Add import: `import 'package:foxyco/ui/settings/profile_controller.dart';`

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/settings_screen_test.dart`
Expected: FAIL — no `TextField` labeled 'Name'.

- [ ] **Step 3: Implement the form**

In `lib/ui/settings/settings_screen.dart`:

Add imports:

```dart
import '../../domain/driver_profile.dart';
import 'profile_controller.dart';
```

At the TOP of the settings `ListView` children (before 'Verdict thresholds'), insert:

```dart
const _SectionLabel('Driver profile'),
const SizedBox(height: Gap.sm + Gap.xs),
const _Card(child: _ProfileForm()),
const SizedBox(height: Gap.lg),
```

Add at the bottom of the file:

```dart
/// Live-apply profile form (spec M5 §3): text fields save on edit, swatch row
/// picks the vehicle color, choice chips pick the body style. No save button —
/// matches the rest of the settings screen.
class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController();
  late final _make = TextEditingController();
  late final _model = TextEditingController();
  late final _year = TextEditingController();
  late final _plate = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [_name, _make, _model, _year, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Seed controllers once from the async-loaded profile — after that the
  /// text fields own their text and only push INTO the provider.
  void _seed(DriverProfile p) {
    if (_seeded && p.name == _name.text) return;
    if (_seeded) return;
    if (p == DriverProfile.empty) return; // still loading or truly empty
    _name.text = p.name;
    _make.text = p.vehicleMake;
    _model.text = p.vehicleModel;
    _year.text = p.vehicleYear;
    _plate.text = p.licensePlate;
    _seeded = true;
  }

  TextField _field(
    TextEditingController c,
    String label,
    void Function(String) onChanged, {
    TextInputType? keyboard,
  }) => TextField(
    controller: c,
    onChanged: onChanged,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label, isDense: true),
  );

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final controller = ref.read(profileProvider.notifier);
    _seed(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_name, 'Name', controller.setName),
        const SizedBox(height: Gap.sm),
        Row(children: [
          Expanded(child: _field(_make, 'Make', controller.setMake)),
          const SizedBox(width: Gap.sm),
          Expanded(child: _field(_model, 'Model', controller.setModel)),
        ]),
        const SizedBox(height: Gap.sm),
        Row(children: [
          Expanded(
            child: _field(_year, 'Year', controller.setYear,
                keyboard: TextInputType.number),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: _field(_plate, 'Plate', controller.setPlate)),
        ]),
        const SizedBox(height: Gap.md),
        // Color swatches — fixed palette, no custom picker.
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final entry in DriverProfile.palette.entries)
              GestureDetector(
                onTap: () => controller.setColor(entry.key),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(entry.key),
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: profile.vehicleColor == entry.key ? 3 : 1,
                      color: profile.vehicleColor == entry.key
                          ? FoxColors.brandFox
                          : FoxColors.textDisabled,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        // Body style chips.
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: [
            for (final t in VehicleType.values)
              ChoiceChip(
                label: Text(t.name),
                selected: profile.vehicleType == t,
                onSelected: (_) => controller.setType(t),
              ),
          ],
        ),
      ],
    );
  }
}
```

(If `_Card` takes a non-const child, drop the `const` before `_Card`.)

- [ ] **Step 4: Run tests**

Run: `flutter test && flutter analyze`
Expected: green, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/settings_screen_test.dart
git commit -m "feat(M5): Settings driver-profile form — live-apply fields, color swatches, type chips"
```

---

### Task 6: Home hero profile card (greeting + vehicle art)

**Files:**
- Create: `lib/ui/home/profile_card.dart` (card + `VehiclePainter`)
- Modify: `lib/ui/home/home_screen.dart` (insert card)
- Test: `test/profile_card_test.dart`

**Interfaces:**
- Consumes: `profileProvider`, `DriverProfile.hasName`, `.vehicleLine`, `.vehicleColor`, `.vehicleType` (Task 4).
- Produces: `class ProfileCard extends ConsumerWidget` — renders `SizedBox.shrink()` when `!hasName`.

- [ ] **Step 1: Write failing widget test**

Create `test/profile_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/ui/home/profile_card.dart';
import 'package:foxyco/ui/settings/profile_controller.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(this._p);
  final DriverProfile _p;
  @override
  DriverProfile build() => _p;
}

Widget _app(DriverProfile p) => ProviderScope(
      overrides: [profileProvider.overrideWith(() => _FixedProfile(p))],
      child: const MaterialApp(home: Scaffold(body: ProfileCard())),
    );

void main() {
  testWidgets('no name → no card', (tester) async {
    await tester.pumpWidget(_app(DriverProfile.empty));
    await tester.pump();
    expect(find.byType(CustomPaint), findsNothing);
    expect(find.textContaining('Good'), findsNothing);
  });

  testWidgets('named profile → greeting + vehicle line + art', (tester) async {
    final p = DriverProfile.empty.copyWith(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.sedan,
    );
    await tester.pumpWidget(_app(p));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    expect(find.textContaining('Red Toyota'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is VehiclePainter,
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/profile_card_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement ProfileCard + VehiclePainter**

Create `lib/ui/home/profile_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/driver_profile.dart';
import '../settings/profile_controller.dart';
import '../theme/tokens.dart';

/// Home hero profile card (spec M5 §3): time-aware greeting, vehicle line,
/// side-view silhouette tinted the profile color. Hidden entirely until the
/// driver gives a name. Entrance fade+slide once; slow sheen loop after —
/// both skipped when the OS asks for reduced motion.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  static String _greeting(String name, DateTime now) {
    final h = now.hour;
    final part = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$part, $name';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (!profile.hasName) return const SizedBox.shrink();

    final card = Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        boxShadow: Shadows.hero,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(profile.name.trim(), DateTime.now()),
                  style: const TextStyle(
                    fontFamily: FoxFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.cream,
                  ),
                ),
                if (profile.vehicleLine.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    profile.vehicleLine,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: FoxColors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          SizedBox(
            width: 96,
            height: 44,
            child: CustomPaint(
              painter: VehiclePainter(
                type: profile.vehicleType,
                color: Color(profile.vehicleColor),
              ),
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.of(context).disableAnimations) return card;
    return _AnimatedEntrance(child: _SheenLoop(child: card));
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
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(_fade);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}

/// Slow low-opacity sheen sweeping the card — long period, subtle.
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

/// Side-view vehicle silhouette: one painter, six path variants, filled with
/// the profile color + simple shading (darker underside, window tint). All
/// coordinates are fractions of the canvas so it scales with its box.
class VehiclePainter extends CustomPainter {
  VehiclePainter({required this.type, required this.color});
  final VehicleType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Path body;
    Path windows;

    switch (type) {
      case VehicleType.sedan:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..lineTo(0.10 * w, 0.55 * h)
          ..lineTo(0.28 * w, 0.50 * h)
          ..lineTo(0.38 * w, 0.28 * h)
          ..lineTo(0.68 * w, 0.28 * h)
          ..lineTo(0.80 * w, 0.50 * h)
          ..lineTo(0.95 * w, 0.58 * h)
          ..lineTo(0.95 * w, 0.75 * h)
          ..close();
        windows = Path()
          ..moveTo(0.40 * w, 0.32 * h)
          ..lineTo(0.66 * w, 0.32 * h)
          ..lineTo(0.75 * w, 0.48 * h)
          ..lineTo(0.32 * w, 0.48 * h)
          ..close();
      case VehicleType.suv:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.07 * w, 0.45 * h)
          ..lineTo(0.20 * w, 0.40 * h)
          ..lineTo(0.30 * w, 0.20 * h)
          ..lineTo(0.78 * w, 0.20 * h)
          ..lineTo(0.88 * w, 0.42 * h)
          ..lineTo(0.95 * w, 0.48 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.33 * w, 0.24 * h)
          ..lineTo(0.76 * w, 0.24 * h)
          ..lineTo(0.83 * w, 0.40 * h)
          ..lineTo(0.26 * w, 0.40 * h)
          ..close();
      case VehicleType.hatchback:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..lineTo(0.09 * w, 0.52 * h)
          ..lineTo(0.25 * w, 0.48 * h)
          ..lineTo(0.36 * w, 0.26 * h)
          ..lineTo(0.72 * w, 0.24 * h)
          ..lineTo(0.90 * w, 0.52 * h)
          ..lineTo(0.92 * w, 0.75 * h)
          ..close();
        windows = Path()
          ..moveTo(0.38 * w, 0.30 * h)
          ..lineTo(0.70 * w, 0.29 * h)
          ..lineTo(0.82 * w, 0.48 * h)
          ..lineTo(0.30 * w, 0.46 * h)
          ..close();
      case VehicleType.pickup:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.07 * w, 0.48 * h)
          ..lineTo(0.16 * w, 0.44 * h)
          ..lineTo(0.24 * w, 0.24 * h)
          ..lineTo(0.50 * w, 0.24 * h)
          ..lineTo(0.54 * w, 0.46 * h)
          ..lineTo(0.95 * w, 0.46 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.27 * w, 0.28 * h)
          ..lineTo(0.47 * w, 0.28 * h)
          ..lineTo(0.50 * w, 0.42 * h)
          ..lineTo(0.20 * w, 0.42 * h)
          ..close();
      case VehicleType.van:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.06 * w, 0.30 * h)
          ..lineTo(0.16 * w, 0.18 * h)
          ..lineTo(0.88 * w, 0.18 * h)
          ..lineTo(0.95 * w, 0.34 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.18 * w, 0.24 * h)
          ..lineTo(0.86 * w, 0.24 * h)
          ..lineTo(0.90 * w, 0.36 * h)
          ..lineTo(0.14 * w, 0.36 * h)
          ..close();
      case VehicleType.motorbike:
        body = Path()
          ..moveTo(0.12 * w, 0.70 * h)
          ..lineTo(0.30 * w, 0.45 * h)
          ..lineTo(0.44 * w, 0.40 * h)
          ..lineTo(0.58 * w, 0.28 * h)
          ..lineTo(0.66 * w, 0.30 * h)
          ..lineTo(0.60 * w, 0.45 * h)
          ..lineTo(0.82 * w, 0.50 * h)
          ..lineTo(0.86 * w, 0.70 * h)
          ..lineTo(0.12 * w, 0.70 * h)
          ..close();
        windows = Path(); // no glass on a bike
    }

    // Body fill + darker underside shading.
    canvas.drawPath(body, Paint()..color = color);
    final underside = Path()
      ..addRect(Rect.fromLTRB(0, 0.60 * h, w, h))
      ..close();
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      underside,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    // Lighter roofline strip.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, 0.32 * h),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();
    // Window tint.
    canvas.drawPath(
      windows,
      Paint()..color = const Color(0xCC22303A),
    );
    // Wheels.
    final wheel = Paint()..color = const Color(0xFF1B1B1B);
    final hub = Paint()..color = const Color(0xFF8A8A8A);
    final r = 0.14 * h * 1.6;
    for (final cx in [0.24 * w, 0.76 * w]) {
      canvas.drawCircle(Offset(cx, 0.78 * h), r, wheel);
      canvas.drawCircle(Offset(cx, 0.78 * h), r * 0.45, hub);
    }
  }

  @override
  bool shouldRepaint(VehiclePainter old) =>
      old.type != type || old.color != color;
}
```

- [ ] **Step 4: Insert the card into HomeScreen**

In `lib/ui/home/home_screen.dart`, add `import 'profile_card.dart';` and insert into the `ListView` children between `const _BrandBar(),` and the `_Hero(...)`:

```dart
const SizedBox(height: Gap.md),
const ProfileCard(),
```

(The card renders `SizedBox.shrink()` with no profile — dashboard identical to today. The extra `SizedBox` collapses visually against the existing `Gap.md` spacing; if double-spacing shows on device, wrap both in a single conditional — acceptable per spec "renders exactly as today".)

Better: replace the existing `const SizedBox(height: Gap.md),` after `_BrandBar` with:

```dart
const SizedBox(height: Gap.md),
const ProfileCard(),
```

and inside `ProfileCard.build`, when `hasName`, return the card wrapped:

```dart
return Padding(
  padding: const EdgeInsets.only(bottom: Gap.md),
  child: /* animated card from above */,
);
```

so spacing only exists when the card does. Apply this padding approach in Step 3's build (wrap the final `return` accordingly: `card`/animated variants get the bottom padding, `SizedBox.shrink()` stays bare).

- [ ] **Step 5: Run tests**

Run: `flutter test && flutter analyze`
Expected: green, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home/profile_card.dart lib/ui/home/home_screen.dart test/profile_card_test.dart
git commit -m "feat(M5): Home hero profile card — greeting, vehicle line, CustomPaint silhouette, sheen"
```

---

### Task 7: Manual monitoring start (WatchStatus.stopped)

**Files:**
- Modify: `lib/ui/home/dashboard_state.dart` (enum)
- Modify: `lib/ui/home/dashboard_controller.dart` (boot state, transitions)
- Modify: `lib/ui/overlay/overlay_controller.dart` (`stopped` → hide)
- Modify: `lib/ui/home/home_screen.dart` (Start Monitoring button)
- Test: `test/dashboard_start_stop_test.dart` (new), `test/overlay_controller_test.dart` (stopped-case), existing tests updated where they assume boot==watching

**Interfaces:**
- Consumes: existing `dashboardProvider`, `overlayControllerProvider` listener.
- Produces: `WatchStatus.stopped`; `DashboardController.startMonitoring()`, `DashboardController.stopMonitoring()`.

- [ ] **Step 1: Write failing tests**

Create `test/dashboard_start_stop_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';

void main() {
  test('boots stopped, never watching', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('startMonitoring → watching; stopMonitoring → stopped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.watching);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('pause layers on top of running; stop from paused works', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    c.togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.paused);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('togglePause is a no-op while stopped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dashboardProvider.notifier).togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/dashboard_start_stop_test.dart`
Expected: FAIL — `WatchStatus.stopped` undefined.

- [ ] **Step 3: Add the enum value + transitions**

`lib/ui/home/dashboard_state.dart` — extend the enum:

```dart
enum WatchStatus {
  /// Live and reading offers.
  watching,

  /// Driver paused it (bubble long-press / Home pause) — temporary mute
  /// while running; Start/Stop is the outer gate.
  paused,

  /// Fully off — user hasn't started monitoring (or explicitly stopped).
  /// The boot state whenever permissions are granted; NEVER persisted as
  /// running across restarts (spec M5 §4, option A).
  stopped,

  /// A required permission is missing — can't watch until fixed.
  blocked,
}
```

`lib/ui/home/dashboard_controller.dart`:

Change `build()`'s return to boot stopped:

```dart
    return const DashboardState(
      status: WatchStatus.stopped,
      permissions: PermissionStatus(
        overlayGranted: true,
        accessibilityGranted: true,
      ),
    );
```

Add the two methods:

```dart
  /// Start Monitoring (spec M5 §4): opens the parse gate and summons the
  /// bubble (overlay controller listens on status). No-op while blocked.
  void startMonitoring() {
    if (state.status == WatchStatus.blocked) return;
    state = _with(status: WatchStatus.watching);
    if (kDebugMode) debugPrint('FoxyCo watch status → watching (started)');
  }

  /// Full stop: overlay torn down, parse gate closed. Works from watching
  /// AND paused (pause is a layer on top of running).
  void stopMonitoring() {
    if (state.status == WatchStatus.blocked ||
        state.status == WatchStatus.stopped) {
      return;
    }
    state = _with(status: WatchStatus.stopped);
    if (kDebugMode) debugPrint('FoxyCo watch status → stopped');
  }
```

Update `togglePause` — pause only layers on a RUNNING watch:

```dart
  void togglePause() {
    if (state.status == WatchStatus.blocked ||
        state.status == WatchStatus.stopped) {
      return;
    }
    final next = state.status == WatchStatus.paused
        ? WatchStatus.watching
        : WatchStatus.paused;
    state = _with(status: next);
    if (kDebugMode) debugPrint('FoxyCo watch status → ${next.name}');
  }
```

Update `refreshPermissions`'s status mapping — granted+idle maps to `stopped`, an explicit running state survives:

```dart
      final WatchStatus status;
      if (!permissions.allGranted) {
        status = WatchStatus.blocked;
      } else if (state.status == WatchStatus.watching ||
          state.status == WatchStatus.paused) {
        status = state.status; // explicit running state survives a refresh
      } else {
        status = WatchStatus.stopped; // granted but user hasn't started
      }
```

`stopWatching()` (bubble drop-to-X) — keep behavior but route to the new full stop (native already closed the window; "dropped the bubble" reads as *stop*, matching the overlay being gone):

```dart
  /// Bubble was dropped on the ✕ target: full stop (the native side already
  /// closed the overlay window, so "stopped" keeps app and overlay in sync).
  void stopWatching() {
    if (state.status != WatchStatus.watching &&
        state.status != WatchStatus.paused) {
      return;
    }
    state = _with(status: WatchStatus.stopped);
    if (kDebugMode) debugPrint('FoxyCo watch status → stopped (bubble dropped)');
  }
```

- [ ] **Step 4: Overlay controller maps stopped → hide**

`lib/ui/overlay/overlay_controller.dart` `_applyStatus` — add the case:

```dart
      case WatchStatus.paused:
      case WatchStatus.blocked:
      case WatchStatus.stopped:
        // Off in any flavor: tear the overlay down — no lingering bubble.
        await _service.hide();
```

- [ ] **Step 5: Start Monitoring button on the dashboard**

`lib/ui/home/home_screen.dart`:

In `_Hero.build`, extend `statusText`:

```dart
    final statusText = switch (status) {
      WatchStatus.watching => 'On the prowl',
      WatchStatus.paused => 'Off duty',
      WatchStatus.stopped => 'Ready when you are',
      WatchStatus.blocked => 'Access needed',
    };
```

In `_ActiveButton.build`, make `stopped` the prominent start CTA (it already renders "Go Live" for any non-watching status — keep that, it now covers `stopped` too). Verify the exhaustive `switch`es in this file compile; any other `switch (status)` gains a `WatchStatus.stopped` arm mirroring `paused`'s visual (dimmed).

In `HomeScreen.build`, wire the button:

```dart
          onToggleActive: switch (state.status) {
            WatchStatus.stopped => controller.startMonitoring,
            WatchStatus.watching ||
            WatchStatus.paused => controller.stopMonitoring,
            WatchStatus.blocked => controller.requestMissingPermissions,
          },
```

(replacing `onToggleActive: controller.togglePause` — the hero button becomes Start/Stop; pause stays on the bubble long-press per spec.)

- [ ] **Step 6: Fix tests that assumed boot==watching**

Run: `flutter test`
Expected failures: `dashboard_resilience_test.dart`, `overlay_controller_test.dart`, possibly `offer_watcher_test.dart`, `widget_test.dart` — anything asserting the default status is `watching` or that the bubble auto-appears.

For each: where the test NEEDS a running watch, call `container.read(dashboardProvider.notifier).startMonitoring()` after setup; where it asserts auto-watching on boot, flip the expectation to `WatchStatus.stopped` (that's the new spec'd behavior). In `overlay_controller_test.dart` add:

```dart
test('stopped status hides the overlay', () async {
  // container/fake setup identical to the existing paused-hides test —
  // start monitoring first, then stop, expect fake.hidden == true.
});
```

(Copy the file's existing paused-case test body and change the transition to `stopMonitoring()`.)

- [ ] **Step 7: Run full suite**

Run: `flutter test && flutter analyze`
Expected: green, clean.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/home/dashboard_state.dart lib/ui/home/dashboard_controller.dart lib/ui/overlay/overlay_controller.dart lib/ui/home/home_screen.dart test/
git commit -m "feat(M5): manual start — WatchStatus.stopped, boot lands stopped, Start/Stop gates overlay+parse"
```

---

### Task 8: Manual test rows + completion doc

**Files:**
- Modify: `docs/MANUAL_TESTS.md`
- Create: `.claude/completions/2026-07-17-m5-polish-and-control.md`

- [ ] **Step 1: Append M5 rows to docs/MANUAL_TESTS.md** (before the closing `_Last updated_` line, update that line's date):

```markdown
## M5 — Polish & Control (2026-07-17)

| # | How | PASS bar | Status |
|---|-----|----------|--------|
| M5.1 | Settings → Pill size Large, tap "Show a demo pill" | Pill renders LARGE (window ~348×100dp); Small/Medium likewise exact | [ ] |
| M5.2 | Change size while a pill is up | Live pill keeps its size; NEXT offer uses the new size | [ ] |
| M5.3 | Drag large pill to either edge | Still draggable — window under 360dp never pins mid-screen | [ ] |
| M5.4 | Drive a session, `adb install -r` a new build, open Settings → Logs | Pre-update lines still present | [ ] |
| M5.5 | Logs → copy | Clipboard holds the tail; Clear (confirm) empties viewer | [ ] |
| M5.6 | Fill profile name+vehicle in Settings, back to Home | Hero card: greeting, vehicle line, tinted silhouette matches type+color | [ ] |
| M5.7 | Clear profile name | Card gone; dashboard exactly as before | [ ] |
| M5.8 | Fresh install, grant both permissions | Bubble does NOT appear until Start Monitoring tapped | [ ] |
| M5.9 | Start → kill app → relaunch | Boots STOPPED (never auto-watching) | [ ] |
| M5.10 | While watching: bubble long-press pause, resume | Pause/resume unchanged, layered under Start/Stop | [ ] |
```

- [ ] **Step 2: Write the completion doc** (summarize files changed, behavior changed, tests, loose ends) per project convention.

- [ ] **Step 3: Final verification**

Run: `flutter analyze && flutter test`
Expected: clean, green.

- [ ] **Step 4: Commit**

```bash
git add docs/MANUAL_TESTS.md .claude/completions/2026-07-17-m5-polish-and-control.md
git commit -m "docs(M5): manual test rows + completion doc"
```
