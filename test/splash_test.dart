import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/splash/splash_screen.dart';
import 'package:go_router/go_router.dart';

/// Wraps the splash in a two-route go_router so we can assert it navigates to
/// the shell. [reduced] forces `disableAnimations` so the reduced-motion path
/// (instant wordmark + short timer) is exercised without touching the window.
Widget _app({bool reduced = false}) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, _) => reduced
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const SplashScreen(),
              )
            : const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('SHELL')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('splash shows wordmark then navigates to the shell', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    // First frame: the FoxyCo wordmark is on the splash, shell not yet. It's the
    // logo image now, and it starts at opacity 0 — which drops it out of the
    // semantics tree — so match the key, not the label.
    expect(find.byKey(const Key('splash-wordmark')), findsOneWidget);
    expect(find.text('SHELL'), findsNothing);

    expect(find.byKey(const Key('splash-car')), findsOneWidget);
    expect(find.byKey(const Key('splash-loader')), findsOneWidget);

    // Let the seasonal drive-in finish and navigate.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('reduced motion skips animation and still reaches the shell', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduced: true));

    // No animation loop — a short timer carries it to the shell.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('splash rotates through all three landscapes', (tester) async {
    await tester.pumpWidget(_app());

    expect(
      find.bySemanticsLabel(RegExp('FoxyCo mountain welcome scene')),
      findsOneWidget,
    );
    await tester.pump(); // Starts the controller after its post-frame callback.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('FoxyCo winter welcome scene')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('FoxyCo autumn welcome scene')),
      findsOneWidget,
    );
  });
}
