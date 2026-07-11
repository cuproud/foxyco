import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/thresholds.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:foxyco/ui/settings/settings_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

Widget _host() => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    );

void main() {
  testWidgets('renders thresholds and live preview', (tester) async {
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
        child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(container.read(settingsProvider), Thresholds.defaults);
  });

  test('controller clamps GOOD above BAD (band stays coherent)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(settingsProvider.notifier);

    // Try to drag GOOD below BAD — it should pin at BAD, never invert.
    c.setGood(0.6);
    expect(container.read(settingsProvider).isValid, isTrue);
    expect(container.read(settingsProvider).goodAtOrAbove,
        container.read(settingsProvider).badBelow);
  });
}
