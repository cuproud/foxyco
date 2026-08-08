import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_skin.dart';
import 'package:foxyco/ui/home/profile_card.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:foxyco/ui/shell/root_shell.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palette tokens are statics, so changing them signals nothing to the element
/// tree — a subtree that isn't rebuilt for some other reason keeps painting the
/// old palette. Switching to dark left Home's greeting in light-mode ink on a
/// dark page until it was scrolled out of the ListView's cache and back (device
/// 2026-07-25). [RootShell] keys the pages on the resolved palette to force the
/// teardown; this is the guard on that.
void main() {
  Color? greetingColor(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(ProfileCard),
      matching: find.byType(RichText),
    );
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<RichText>(finder.first).text.style?.color;
  }

  testWidgets('switching skin repaints subtrees that nothing else rebuilds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(driverNameProvider.notifier).setName('Vamsi');
    container.read(settingsProvider.notifier).setSkin(AppSkin.light);

    // Mirror main.dart: apply the palette, then build the theme from it.
    Widget app(AppSkin skin) {
      final palette = skin == AppSkin.light
          ? FoxPalette.light
          : FoxPalette.dark;
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(palette),
          home: const RootShell(),
        ),
      );
    }

    // pump(), not pumpAndSettle(): Home runs idle loops (the breathing dot,
    // the car glow pulse, the marching chevrons) that never settle.
    await tester.pumpWidget(app(AppSkin.light));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      greetingColor(tester),
      FoxPalette.light.textPrimary,
      reason: 'greeting should start in light-mode ink',
    );

    // Flip the setting AND the built theme, exactly as the real switch does.
    container.read(settingsProvider.notifier).setSkin(AppSkin.dark);
    await tester.pumpWidget(app(AppSkin.dark));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      greetingColor(tester),
      FoxPalette.dark.textPrimary,
      reason:
          'greeting kept the light palette after the switch — the page subtree '
          'was not torn down, so the static tokens it baked in went stale',
    );
  });
}
