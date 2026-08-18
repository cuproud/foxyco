import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxyco/router.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/onboarding/onboarding_screen.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';

class _GrantedDashboardController extends DashboardController {
  @override
  DashboardState build() => const DashboardState(
    status: WatchStatus.stopped,
    permissions: PermissionStatus(
      overlayGranted: true,
      accessibilityGranted: true,
    ),
  );
}

void main() {
  // The wizard now AWAITS its prefs writes (driver name + the onboarded flag)
  // before navigating, so an exit only completes if the plugin answers.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app({required bool showOnboarding}) => ProviderScope(
    overrides: [
      dashboardProvider.overrideWith(_GrantedDashboardController.new),
    ],
    child: MaterialApp.router(
      routerConfig: createRouter(showOnboarding: showOnboarding),
    ),
  );

  testWidgets('first run boots into onboarding page 1', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining('Meet FoxyCo'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('returning run boots straight to Home', (tester) async {
    await tester.pumpWidget(app(showOnboarding: false));
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget); // Home brand bar
  });

  testWidgets('Next walks the 5 pages; preset applies; grant state shows; '
      'last page CTA exits to Home', (tester) async {
    final container = ProviderContainer(
      overrides: [
        dashboardProvider.overrideWith(_GrantedDashboardController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: createRouter(showOnboarding: true),
        ),
      ),
    );

    // Page 2 — threshold preset. Tapping Picky writes straight to settings.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Set your bar'), findsOneWidget);
    // The page scrolls (small screens, large font scale, and now the consent
    // line in the footer), so scroll the preset into view before tapping it —
    // a tap on a half-clipped widget silently misses.
    await tester.ensureVisible(find.text('Picky'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picky'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).thresholds.goodAtOrAbove, 1.8);

    // Page 3 — one-time purchase promise; no subscription language.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Try a week. Pay once.'), findsOneWidget);
    expect(find.textContaining('no subscription'), findsOneWidget);

    // Page 4 — overlay grant. Off-device the dashboard defaults both grants
    // to true (plugin channels absent), so the page shows the granted chip.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Display over other apps'), findsOneWidget);
    expect(find.text('✅ Granted'), findsOneWidget);

    // Page 5 — accessibility grant, with the plain-language disclosure.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Offer access'), findsOneWidget);
    expect(find.text('✅ Granted'), findsOneWidget);
    expect(
      find.textContaining('cannot tap, accept, decline'),
      findsOneWidget,
      reason: 'strictly-manual disclosure must be on the accessibility page',
    );

    // Final CTA replaces Next and lands on Home.
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Start driving smarter'));
    // Home's car hero runs an endless idle loop — pumpAndSettle would hang.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget);
  });

  testWidgets('name typed on page 1 lands in Home\'s greeting', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    // Padded on purpose — the name is trimmed on the way out.
    await tester.enterText(find.byType(TextField), '  Vamsi  ');
    await tester.tap(find.text('Skip for now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // ProfileCard hides itself on an empty name, so this only passes if the
    // wizard actually saved one.
    expect(find.textContaining('Vamsi'), findsOneWidget);
  });

  testWidgets('Skip for now exits to Home from page 1', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    await tester.tap(find.text('Skip for now'));
    // Home's car hero runs an endless idle loop — pumpAndSettle would hang.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget);
  });
}
