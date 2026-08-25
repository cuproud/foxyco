import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/ui/home/home_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';

Widget _app(SessionSummary session, {FoxPalette palette = FoxPalette.dark}) {
  final theme = AppTheme.of(palette);
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SessionPerformance(
          session: session,
          settings: FoxSettings.defaults,
          text: theme.textTheme,
        ),
      ),
    ),
  );
}

SessionSummary _session({double estimatedEarnings = 0}) => SessionSummary(
  startedAt: DateTime(2026, 7, 20, 6),
  endedAt: DateTime(2026, 7, 20, 9),
  good: 1,
  ok: 17,
  bad: 38,
  accepted: estimatedEarnings > 0 ? 6 : 0,
  estimatedEarnings: estimatedEarnings,
  bestPerKm: 2.23,
  goodAvgPerKm: 1.51,
  busiestHour: 9,
);

void main() {
  testWidgets('keeps the session performance metrics readable', (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_session()));

    expect(find.text('No accepted offers this session'), findsOneWidget);
    expect(find.text('Est. earnings'), findsNothing);
    await tester.tap(find.text('No accepted offers this session'));
    await tester.pumpAndSettle();

    expect(find.text('Est. earnings'), findsOneWidget);
    expect(find.text('Accepted offers only'), findsOneWidget);
    expect(find.text('Session rate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('available earnings remain aligned with larger values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_session(estimatedEarnings: 126.40)));

    expect(find.text(r'$126.40   |   $42/hr'), findsOneWidget);
    final collapsed = tester.widget<Text>(
      find.byKey(const ValueKey('session-performance-collapsed')),
    );
    final earningsSpan =
        (collapsed.textSpan! as TextSpan).children!.first as TextSpan;
    expect(earningsSpan.style?.color, FoxColors.brandFox);
    await tester.tap(find.text(r'$126.40   |   $42/hr'));
    await tester.pumpAndSettle();

    expect(find.text(r'$126.40'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('session-performance-earnings')),
          )
          .style
          ?.color,
      FoxColors.brandFox,
    );
    expect(find.text('Trip payouts'), findsOneWidget);
    expect(find.text(r'$42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('light theme uses the deeper earnings accent', (tester) async {
    await tester.pumpWidget(
      _app(_session(estimatedEarnings: 126.40), palette: FoxPalette.light),
    );

    final collapsed = tester.widget<Text>(
      find.byKey(const ValueKey('session-performance-collapsed')),
    );
    final earningsSpan =
        (collapsed.textSpan! as TextSpan).children!.first as TextSpan;
    expect(earningsSpan.style?.color, FoxColors.brandFoxDeep);

    await tester.tap(find.text(r'$126.40   |   $42/hr'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('session-performance-earnings')),
          )
          .style
          ?.color,
      FoxColors.brandFoxDeep,
    );
  });
}
