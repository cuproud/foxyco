import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/router.dart';
import 'package:foxyco/ui/onboarding/onboarding_screen.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';

void main() {
  Widget app({required bool showOnboarding}) => ProviderScope(
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

  testWidgets('Next walks the 4 pages; preset applies; grant state shows; '
      'last page CTA exits to Home', (tester) async {
    final container = ProviderContainer();
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
    await tester.tap(find.text('Picky'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).thresholds.goodAtOrAbove, 1.8);

    // Page 3 — overlay grant. Off-device the dashboard defaults both grants
    // to true (plugin channels absent), so the page shows the granted chip.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Draw over other apps'), findsOneWidget);
    expect(find.text('✅ Granted'), findsOneWidget);

    // Page 4 — accessibility grant, with the plain-language disclosure.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read the offer on screen'), findsOneWidget);
    expect(find.text('✅ Granted'), findsOneWidget);
    expect(
      find.textContaining('never taps buttons'),
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
