import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/ui/home/home_screen.dart';

Widget _app(SessionSummary session) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: SessionPerformance(
        session: session,
        settings: FoxSettings.defaults,
        text: ThemeData.dark().textTheme,
      ),
    ),
  ),
);

SessionSummary _session({double estimatedEarnings = 0}) => SessionSummary(
  startedAt: DateTime(2026, 7, 20, 6),
  endedAt: DateTime(2026, 7, 20, 9),
  good: 1,
  ok: 17,
  bad: 38,
  accepted: 6,
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

    expect(find.text('—   |   —'), findsOneWidget);
    expect(find.text('Est. earnings'), findsNothing);
    await tester.tap(find.text('—   |   —'));
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
    await tester.tap(find.text(r'$126.40   |   $42/hr'));
    await tester.pumpAndSettle();

    expect(find.text(r'$126.40'), findsOneWidget);
    expect(find.text('Trip payouts'), findsOneWidget);
    expect(find.text(r'$42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
