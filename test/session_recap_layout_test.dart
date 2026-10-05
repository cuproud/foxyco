import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/services/session_log.dart';
import 'package:foxyco/ui/home/home_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sessions extends SessionLog {
  @override
  List<SessionSummary> build() {
    final yesterday = DateUtils.dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    return [
      SessionSummary(
        startedAt: yesterday.add(const Duration(hours: 12, minutes: 50)),
        endedAt: yesterday.add(const Duration(hours: 16, minutes: 49)),
        bad: 54,
        accepted: 4,
        estimatedEarnings: 99.13,
      ),
    ];
  }
}

void main() {
  testWidgets('recap date and both time chips share one row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('fonts/Inter.ttf'))).load();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('foxyco/play_updates/events'),
      (_) async => null,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => FoxColors.apply(FoxPalette.dark));
    for (final width in [320.0, 360.0, 412.0]) {
      for (final palette in [FoxPalette.light, FoxPalette.dark]) {
        tester.view.physicalSize = const Size(600, 1000);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionLogProvider.overrideWith(_Sessions.new)],
            child: MaterialApp(
              theme: AppTheme.of(palette),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final cardFinder = find.byKey(const Key('session-recap-card'));
        await tester.ensureVisible(cardFinder);
        await tester.pump();
        final card = tester.widget<Container>(cardFinder);
        tester.view.physicalSize = Size(width, 1000);
        // Isolate the existing recap to check its layout at enlarged text too.
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.of(palette),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: card,
                ),
              ),
            ),
          );
          await tester.pump();
          final date = find.text('Yesterday');
          final time = find.text('12:50 PM – 4:49 PM');
          final active = find.text('3h 59m active');
          if (scale == 1) {
            expect(
              tester.getCenter(date).dy,
              closeTo(tester.getCenter(time).dy, .1),
            );
            expect(
              tester.getTopLeft(time).dy,
              closeTo(tester.getTopLeft(active).dy, .1),
            );
            expect(
              tester.getTopLeft(active).dx,
              greaterThan(tester.getTopRight(time).dx),
            );
          }
          if (scale > 1.3) {
            expect(
              tester.getBottomLeft(date).dy,
              lessThan(tester.getTopLeft(time).dy),
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '$width dp / $scale / ${palette.brightness}',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
