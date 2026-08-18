import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_currency.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/rate_mode.dart';
import 'package:foxyco/domain/thresholds.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:foxyco/ui/overlay/verdict_pill.dart';
import 'package:foxyco/ui/rules/rules_screen.dart';
import 'package:foxyco/ui/settings/settings_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SettingsScreen lives inside RootShell's Scaffold (which supplies the Material
// ancestor its Sliders need); mirror that here.
Widget _host() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: SettingsScreen()),
  ),
);

Widget _rulesHost() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: RulesScreen()),
  ),
);

/// Groups start collapsed (except Driver); open one before asserting on its
/// body widgets. Single-open means opening a group closes the previous one.
Future<void> openGroup(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void expectNoLayoutError(WidgetTester tester, String phase) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason:
        '$phase\n${error is FlutterError ? error.toStringDeep() : error}'
        '${error == null ? '' : _overflowingRows()}',
  );
}

String _overflowingRows() {
  final found = <String>[];
  for (final element in find.byType(Row).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderFlex || !render.hasSize) continue;
    var left = 0.0;
    var right = render.size.width;
    var child = render.firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      left = left < data.offset.dx ? left : data.offset.dx;
      final childRight = data.offset.dx + child.size.width;
      right = right > childRight ? right : childRight;
      child = data.nextSibling;
    }
    final overflow = (-left) + (right - render.size.width);
    if (overflow > 0.1) {
      found.add(
        '\nOverflowing Row (${overflow.toStringAsFixed(1)} px): '
        '${render.debugCreator}\n${render.toStringDeep()}',
      );
    }
  }
  return found.isEmpty
      ? '\nNo explicit Row bounds exceeded; inspect an internal Flex.'
      : found.join();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders thresholds and live preview', (tester) async {
    // Tall viewport so the lazy ListView builds every collapsed group.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());

    expect(find.text('My Rules'), findsOneWidget);

    // Core controls are open by default for one-tap access from the nav.
    expect(find.text('GOOD at or above'), findsOneWidget);
    expect(find.text('BAD below'), findsOneWidget);

    // Live preview is a separate group; opening it collapses thresholds.
    await openGroup(tester, 'Live preview');
    // Live preview uses the same production pill rendered by the overlay.
    expect(find.byType(VerdictPill), findsOneWidget);
    expect(find.text('GOOD'), findsWidgets);
    expect(find.text('At or under 2.0 km'), findsOneWidget);
    expect(find.text('Offer price'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.byKey(const Key('rules_try_example')), findsOneWidget);
  });

  testWidgets('floating bubble picker shows and saves all three styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await openGroup(tester, 'Appearance');
    await tester.tap(find.text('Floating bubble'));
    await tester.pumpAndSettle();

    expect(find.text('Cool Fox'), findsAtLeastNWidgets(1));
    expect(find.text('FoxyCo F'), findsAtLeastNWidgets(1));
    expect(find.text('Fox Paw'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Fox Paw'));
    await tester.pumpAndSettle();
    expect(find.text('Fox Paw'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(settingsProvider).bubbleStyle.name,
      'foxPaw',
    );
  });

  testWidgets('live preview examples cycle through OK, BAD, and GOOD', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());
    await openGroup(tester, 'Live preview');

    final button = find.byKey(const Key('rules_try_example'));
    await tester.tap(button);
    await tester.pump();
    expect(find.text('OK'), findsWidgets);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('BAD'), findsWidgets);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('GOOD'), findsWidgets);
  });

  testWidgets('voice verdict master dims its child controls when off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());

    await openGroup(tester, 'Voice announcements');
    final toggle = find.byKey(const Key('rules_voice_toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.byKey(const Key('rules_voice_preview')), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.byKey(const Key('rules_voice_good_toggle')), findsOneWidget);
    expect(find.byKey(const Key('rules_voice_ok_toggle')), findsOneWidget);
    expect(find.byKey(const Key('rules_voice_cooldown')), findsOneWidget);
  });

  testWidgets('threshold presets remain visible in hourly mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());

    expect(find.text('Relaxed'), findsOneWidget);
    await tester.tap(find.text(r'$/hr'));
    await tester.pumpAndSettle();
    expect(find.text('Relaxed'), findsOneWidget);

    await tester.tap(find.text('Picky'));
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(RulesScreen)),
    ).read(settingsProvider);
    expect(
      settings.hourThresholds,
      const Thresholds(goodAtOrAbove: 36, badBelow: 24),
    );
  });

  testWidgets('minimum payout rule exposes amount without a verdict selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());

    await openGroup(tester, 'Offer guard');
    final toggle = find.byKey(const Key('rules_minimum_payout_toggle'));
    expect(toggle, findsOneWidget);
    expect(find.byKey(const Key('rules_minimum_payout_verdict')), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('BAD if offer is below'), findsOneWidget);
    expect(find.byKey(const Key('rules_minimum_payout_verdict')), findsNothing);
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
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    // Header Reset opens a confirm dialog (destructive gate); confirm it.
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset all settings?'), findsOneWidget);
    await tester.tap(find.text('Reset').last); // dialog's confirm action
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).thresholds, Thresholds.defaults);
  });

  testWidgets('Reset cancel keeps tuned settings', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setGood(2.5);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).thresholds.goodAtOrAbove, 2.5);
  });

  testWidgets('pill size selector shows live VerdictPill preview', (
    tester,
  ) async {
    // Tall viewport so the lazy ListView builds the pill-size section.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await openGroup(tester, 'Pill size');

    // Preview pill is rendered on the settings screen.
    expect(find.byType(VerdictPill), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(VerdictPill),
        matching: find.text(r'CA$1.43'),
      ),
      findsOneWidget,
    );
    // Selecting Large re-renders the preview at the large size.
    final smallSize = tester.getSize(find.byType(VerdictPill));
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    final largeSize = tester.getSize(find.byType(VerdictPill));
    expect(largeSize.height, greaterThan(smallSize.height));
    final selected = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('choice_Large')),
    );
    expect(
      (selected.decoration! as BoxDecoration).color,
      FoxColors.brandFoxSoft,
    );
  });

  testWidgets('driver name saves on the check button, not live', (
    tester,
  ) async {
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

    // Saved → display mode: plain text + pencil, no TextField.
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Name'), findsNothing);
    expect(find.byKey(const ValueKey('edit-name')), findsOneWidget);

    // Pencil → back to the editable field.
    await tester.tap(find.byKey(const ValueKey('edit-name')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
  });

  testWidgets('garage section offers an add-vehicle affordance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await openGroup(tester, 'Garage');
    expect(find.byKey(const ValueKey('add-vehicle')), findsOneWidget);
    expect(find.text('Add vehicle'), findsOneWidget);
  });

  testWidgets('font picker shows samples saves choice', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await openGroup(tester, 'Appearance');
    // One live "$24.50" sample per MoneyFont value.
    expect(find.text(r'$24.50'), findsNWidgets(3));

    await tester.tap(find.text('Space Grotesk'));
    await tester.pumpAndSettle();
    // Summary line + card label both reflect the pick.
    expect(find.text('Space Grotesk'), findsWidgets);
  });

  testWidgets('Pixel Capture is an opt-in parser fallback', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await openGroup(tester, 'Offer detection');
    expect(find.text('Pixel Capture (OCR)'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Pixel Capture (OCR)'),
    );
    expect(toggle.value, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('ocr_test_mode_toggle')))
          .onChanged,
      isNull,
    );
    await tester.tap(find.text('Pixel Capture (OCR)'));
    await tester.pumpAndSettle();
    expect(find.text('Enable on-device Pixel Capture?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('This session'), findsOneWidget);

    await tester.tap(find.text('Pixel Capture (OCR)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable OCR'));
    await tester.pumpAndSettle();
    expect(find.text('This session · OCR enabled'), findsOneWidget);

    final testToggle = find.byKey(const Key('ocr_test_mode_toggle'));
    expect(tester.widget<SwitchListTile>(testToggle).onChanged, isNotNull);
    await tester.tap(testToggle);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsScreen));
    expect(
      ProviderScope.containerOf(context).read(settingsProvider).ocrTestMode,
      isTrue,
    );
  });

  testWidgets('accordion opens one group at a time', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_rulesHost());
    await tester.pumpAndSettle();

    // Watched apps' switch tiles are hidden while the group is collapsed.
    expect(find.text('Uber'), findsNothing);

    await openGroup(tester, 'Watched apps');
    expect(find.text('Uber'), findsOneWidget);

    // Opening another group collapses the previous one.
    await openGroup(tester, 'Live preview');
    expect(find.text('Uber'), findsNothing);
    expect(find.text('See how your rules score an offer'), findsOneWidget);
  });

  testWidgets('groups are filed under named bands, in band order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // Operational settings remain grouped after scoring rules move out.
    for (final band in const [
      'YOU & YOUR CAR',
      'DIAGNOSTICS',
      'LOOK & FEEL',
      'YOUR DATA',
    ]) {
      expect(find.text(band), findsOneWidget, reason: band);
    }

    // Vertical order is the contract — a band header sits above its groups.
    double y(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(y('YOU & YOUR CAR'), lessThan(y('Profile')));
    expect(y('DIAGNOSTICS'), lessThan(y('Offer detection')));
    expect(y('Offer detection'), lessThan(y('Outcome tracking')));
    expect(y('LOOK & FEEL'), greaterThan(y('Outcome tracking')));
    expect(y('YOUR DATA'), lessThan(y('History')));
    expect(y('History'), lessThan(y('Logs')));
  });

  testWidgets('History actions fit narrow screens', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expectNoLayoutError(tester, 'Initial Settings layout');
    final settingsScroll = find.descendant(
      of: find.byKey(const Key('settings_scroll')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(settingsScroll, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('History'),
      300,
      scrollable: settingsScroll,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('History'));
    await tester.pump();
    expectNoLayoutError(tester, 'Collapsed History header');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expectNoLayoutError(tester, 'Expanded History controls');
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_actions')),
      200,
      scrollable: settingsScroll,
    );
    await tester.pumpAndSettle();

    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Clear offer history'), findsOneWidget);
    expectNoLayoutError(tester, 'Visible History actions');
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

  test('OCR opt-in survives a JSON round-trip and defaults off', () {
    expect(FoxSettings.fromJson(const {}).ocrEnabled, isFalse);
    final back = FoxSettings.fromJson(
      FoxSettings.defaults.copyWith(ocrEnabled: true).toJson(),
    );
    expect(back.ocrEnabled, isTrue);
    expect(
      FoxSettings.fromJson(
        FoxSettings.defaults.copyWith(ocrTestMode: true).toJson(),
      ).ocrTestMode,
      isFalse,
      reason: 'debug test mode must not persist',
    );
  });

  test('voice settings survive a JSON round-trip with GOOD default on', () {
    expect(FoxSettings.fromJson(const {}).announceGoodOffers, isTrue);
    expect(FoxSettings.fromJson(const {}).voiceVerdictEnabled, isTrue);
    final back = FoxSettings.fromJson(
      FoxSettings.defaults
          .copyWith(
            voiceVerdictEnabled: false,
            announceGoodOffers: false,
            announceOkOffers: true,
            goodVoiceMinimumPayout: 42,
            okVoiceMinimumPayout: 18,
            voiceCooldownSeconds: 45,
          )
          .toJson(),
    );
    expect(back.announceGoodOffers, isFalse);
    expect(back.voiceVerdictEnabled, isFalse);
    expect(back.announceOkOffers, isTrue);
    expect(back.goodVoiceMinimumPayout, 42);
    expect(back.okVoiceMinimumPayout, 18);
    expect(back.voiceCooldownSeconds, 45);
  });

  test('minimum payout rule round-trips and defaults disabled', () {
    expect(FoxSettings.fromJson(const {}).minimumPayoutEnabled, isFalse);
    final settings = FoxSettings.defaults.copyWith(
      minimumPayoutEnabled: true,
      minimumPayout: 7.5,
      minimumPayoutVerdict: Verdict.ok,
    );
    final back = FoxSettings.fromJson(settings.toJson());
    expect(back.minimumPayoutEnabled, isTrue);
    expect(back.minimumPayout, 7.5);
    expect(back.minimumPayoutVerdict, Verdict.ok);
  });

  test('disabling OCR also clears its test override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);

    controller.setOcrEnabled(true);
    controller.setOcrTestMode(true);
    expect(container.read(settingsProvider).ocrTestMode, isTrue);

    controller.setOcrEnabled(false);
    expect(container.read(settingsProvider).ocrTestMode, isFalse);
  });

  test(r'old saved blobs (no rateMode keys) load with $/km defaults', () {
    // A pre-rate-mode settings blob: only km cuts present.
    final back = FoxSettings.fromJson({'good': 1.8, 'bad': 0.9});
    expect(back.rateMode, RateMode.perKm);
    expect(
      back.thresholds,
      const Thresholds(goodAtOrAbove: 1.8, badBelow: 0.9),
    );
    expect(back.hourThresholds, FoxSettings.defaultHourThresholds);
  });

  test('mile threshold and pickup edits are stored canonically', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    controller.setDistanceUnit(DistanceUnit.miles);
    controller.setDisplayedGood(1.609344);
    controller.setDisplayedPickupNear(1);

    final settings = container.read(settingsProvider);
    expect(settings.thresholds.goodAtOrAbove, closeTo(1, 1e-9));
    expect(settings.pickupNearKm, closeTo(1.609344, 1e-9));
  });

  test('currency selects its conventional distance unit', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    final thresholds = container.read(settingsProvider).thresholds;

    controller.setCurrency(AppCurrency.usd);
    expect(container.read(settingsProvider).distanceUnit, DistanceUnit.miles);

    controller.setCurrency(AppCurrency.cad);
    expect(
      container.read(settingsProvider).distanceUnit,
      DistanceUnit.kilometres,
    );

    for (final currency in const [
      AppCurrency.aud,
      AppCurrency.nzd,
      AppCurrency.mxn,
      AppCurrency.brl,
    ]) {
      controller.setCurrency(currency);
      expect(
        container.read(settingsProvider).distanceUnit,
        DistanceUnit.kilometres,
      );
    }
    expect(
      container.read(settingsProvider).thresholds,
      thresholds,
      reason: 'currency selection labels values; it never performs FX',
    );
  });

  test('supported storefront countries map to requested currencies', () {
    expect(AppCurrency.fromCountryCode('US'), AppCurrency.usd);
    expect(AppCurrency.fromCountryCode('ca'), AppCurrency.cad);
    expect(AppCurrency.fromCountryCode('AU'), AppCurrency.aud);
    expect(AppCurrency.fromCountryCode('NZ'), AppCurrency.nzd);
    expect(AppCurrency.fromCountryCode('MX'), AppCurrency.mxn);
    expect(AppCurrency.fromCountryCode('BR'), AppCurrency.brl);
    expect(AppCurrency.fromCountryCode('GB'), AppCurrency.cad);
  });

  test('persisted settings are clamped to supported controls', () {
    final settings = FoxSettings.fromJson({
      'good': 99,
      'bad': -4,
      'hourGood': 1000,
      'hourBad': -1,
      'pickupNearKm': 500,
      'retentionDays': 13,
    });

    expect(
      settings.thresholds,
      const Thresholds(goodAtOrAbove: 3, badBelow: 0.5),
    );
    expect(
      settings.hourThresholds,
      const Thresholds(goodAtOrAbove: 60, badBelow: 10),
    );
    expect(settings.pickupNearKm, 10);
    expect(settings.retentionDays, FoxSettings.defaults.retentionDays);
  });
}
