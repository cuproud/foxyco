import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/rate_mode.dart';
import 'package:foxyco/domain/thresholds.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:foxyco/ui/overlay/verdict_pill.dart';
import 'package:foxyco/ui/settings/settings_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SettingsScreen lives inside RootShell's Scaffold (which supplies the Material
// ancestor its Sliders need); mirror that here.
Widget _host() => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SettingsScreen()),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders thresholds and live preview', (tester) async {
    // Tall viewport so the lazy ListView builds the bottom preview card.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('GOOD at or above'), findsOneWidget);
    expect(find.text('BAD below'), findsOneWidget);
    // Default band: GOOD ≥ 1.50 sample offer at 1.25 ⇒ OK.
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('Reset restores defaults', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setGood(2.5);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: SettingsScreen())),
      ),
    );

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(container.read(settingsProvider).thresholds, Thresholds.defaults);
  });

  testWidgets('pill size selector shows live VerdictPill preview',
      (tester) async {
    // Tall viewport so the lazy ListView builds the pill-size section.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
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

  testWidgets('driver name saves on the check button, not live',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'Name');
    expect(nameField, findsOneWidget);

    final ctx = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(ctx);

    // Typing alone does not persist — the check button must appear.
    await tester.enterText(nameField, 'Vamsi');
    await tester.pump();
    expect(container.read(driverNameProvider), '');
    expect(find.byKey(const ValueKey('save-name')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-name')));
    await tester.pump();
    expect(container.read(driverNameProvider), 'Vamsi');
  });

  testWidgets('garage section offers an add-vehicle affordance',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-vehicle')), findsOneWidget);
    expect(find.text('Add vehicle'), findsOneWidget);
  });

  test('controller clamps GOOD above BAD (band stays coherent)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(settingsProvider.notifier);

    // Try to drag GOOD below BAD — it should pin at BAD, never invert.
    c.setGood(0.6);
    final t = container.read(settingsProvider).thresholds;
    expect(t.isValid, isTrue);
    expect(t.goodAtOrAbove, t.badBelow);
  });

  test(r'rate-mode switch keeps per-mode cut points independent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(settingsProvider.notifier);

    // In $/hr mode the sliders edit the HOUR cuts…
    c.setRateMode(RateMode.perHour);
    c.setGood(45);
    c.setBad(25);
    var s = container.read(settingsProvider);
    expect(s.hourThresholds, const Thresholds(goodAtOrAbove: 45, badBelow: 25));
    // …and the km cuts are untouched.
    expect(s.thresholds, Thresholds.defaults);
    expect(s.activeThresholds, s.hourThresholds);

    // Switching back re-activates the km cuts unchanged.
    c.setRateMode(RateMode.perKm);
    s = container.read(settingsProvider);
    expect(s.activeThresholds, Thresholds.defaults);
    expect(s.hourThresholds, const Thresholds(goodAtOrAbove: 45, badBelow: 25));
  });

  test(r'$/hr band stays coherent under the same clamps', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(settingsProvider.notifier);

    c.setRateMode(RateMode.perHour);
    c.setGood(15); // below the default BAD cut (20) — must pin, not invert
    final t = container.read(settingsProvider).hourThresholds;
    expect(t.isValid, isTrue);
    expect(t.goodAtOrAbove, t.badBelow);
  });

  test('rate mode + hour cuts survive a JSON round-trip', () {
    final s = FoxSettings.defaults.copyWith(
      rateMode: RateMode.perHour,
      hourThresholds: const Thresholds(goodAtOrAbove: 42, badBelow: 21),
    );
    final back = FoxSettings.fromJson(s.toJson());
    expect(back.rateMode, RateMode.perHour);
    expect(back.hourThresholds, s.hourThresholds);
    expect(back.thresholds, s.thresholds);
  });

  test(r'old saved blobs (no rateMode keys) load with $/km defaults', () {
    // A pre-rate-mode settings blob: only km cuts present.
    final back = FoxSettings.fromJson({'good': 1.8, 'bad': 0.9});
    expect(back.rateMode, RateMode.perKm);
    expect(back.thresholds, const Thresholds(goodAtOrAbove: 1.8, badBelow: 0.9));
    expect(back.hourThresholds, FoxSettings.defaultHourThresholds);
  });
}
