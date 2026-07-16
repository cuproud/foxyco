import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/router.dart';
import 'package:foxyco/ui/onboarding/onboarding_screen.dart';

void main() {
  Widget app({required bool showOnboarding}) => ProviderScope(
    child: MaterialApp.router(
      routerConfig: createRouter(showOnboarding: showOnboarding),
    ),
  );

  testWidgets('first run boots into onboarding page 1', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Meet FoxyCo'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('returning run boots straight to Home', (tester) async {
    await tester.pumpWidget(app(showOnboarding: false));
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget); // Home brand bar
  });

  testWidgets('Next walks the 3 pages; grant state shows; '
      'last page CTA exits to Home', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    // Page 2 — overlay grant. Off-device the dashboard defaults both grants
    // to true (plugin channels absent), so the page shows the granted chip.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Draw over other apps'), findsOneWidget);
    expect(find.text('✅ Granted'), findsOneWidget);

    // Page 3 — accessibility grant, with the plain-language disclosure.
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
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget);
  });

  testWidgets('Skip for now exits to Home from page 1', (tester) async {
    await tester.pumpWidget(app(showOnboarding: true));

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('FoxyCo'), findsOneWidget);
  });
}
