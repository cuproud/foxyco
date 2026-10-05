import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/splash/splash_screen.dart';
import 'package:go_router/go_router.dart';

Widget _app({bool reduced = false, bool tickers = true}) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: TickerMode(enabled: tickers, child: const SplashScreen()),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('SHELL')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('composite splash finishes at 1.8 seconds', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byKey(const Key('splash-key-art')), findsOneWidget);
    expect(find.text('SHELL'), findsNothing);
    final artwork = tester.element(find.byKey(const Key('splash-key-art')));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const Key('splash-glint')), findsOneWidget);
    expect(
      tester.element(find.byKey(const Key('splash-key-art'))),
      same(artwork),
    );
    await tester.pump(const Duration(milliseconds: 790));
    expect(find.text('SHELL'), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('reduced motion stays static and exits at 450 ms', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduced: true));
    expect(find.byKey(const Key('splash-glint')), findsNothing);
    final image = find.byKey(const Key('splash-key-art'));
    final transforms = find.ancestor(
      of: image,
      matching: find.byType(Transform),
    );
    for (final transform in tester.widgetList<Transform>(transforms)) {
      expect(transform.transform, Matrix4.identity());
    }
    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text('SHELL'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('2.6 second ceiling works with suspended animation ticks', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tickers: false));
    await tester.pump(const Duration(milliseconds: 2599));
    expect(find.text('SHELL'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('disposing splash cancels navigation callbacks', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const MaterialApp(home: Text('REPLACEMENT')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('REPLACEMENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 640),
    Size(360, 800),
    Size(360, 900),
    Size(412, 736),
    Size(412, 915),
    Size(800, 360),
  ]) {
    testWidgets('artwork focal area fits $size with Android system insets', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/foxyco_golden_mountain_drive.png'),
          tester.element(find.byType(SplashScreen)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      final image = tester.widget<Image>(
        find.byKey(const Key('splash-key-art')),
      );
      final fit = image.fit!;
      final artScale = fit == BoxFit.cover
          ? math.max(size.width / 863, size.height / 1822)
          : math.min(size.width / 863, size.height / 1822);
      // Independent projection of the baked-in fox, logo and tagline bounds
      // after the largest camera move. They must avoid both system bars.
      final w = 863 * artScale * 1.025;
      final h = 1822 * artScale * 1.025;
      final left = (size.width - w) / 2;
      final top = (size.height - h) / 2 - 5;
      final focal = Rect.fromLTRB(
        left + w * .15,
        top + h * .35,
        left + w * .86,
        top + h * .79,
      );
      expect(focal.left, greaterThanOrEqualTo(0));
      expect(focal.right, lessThanOrEqualTo(size.width));
      expect(focal.top, greaterThanOrEqualTo(28));
      expect(focal.bottom, lessThanOrEqualTo(size.height - 24));
      final style = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is AnnotatedRegion<SystemUiOverlayStyle> &&
                      w.value.systemNavigationBarContrastEnforced == false,
                )
                .first,
          )
          .value;
      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  }
}
