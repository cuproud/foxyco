import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/ui/home/goal_card.dart';

void main() {
  testWidgets('goal uses taken earnings and switches periods', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 9, 19, 12);
    OfferSummary offer(double payout, OfferOutcome outcome) => OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.good,
      payout: payout,
      totalKm: 10,
      seenAt: DateTime(2026, 9, 18, 18),
      outcome: outcome,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalCard(
            offers: [
              offer(360, OfferOutcome.completed),
              offer(500, OfferOutcome.missed),
            ],
            settings: FoxSettings.defaults,
            now: now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly goal'), findsOneWidget);
    expect(find.textContaining(r'$360'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goal-month')));
    await tester.pumpAndSettle();

    expect(find.text('Monthly goal'), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);
  });

  testWidgets('goal can be edited and large amounts fit', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    EarningsGoalPeriod? changedPeriod;
    double? changedAmount;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalCard(
            offers: const [],
            settings: FoxSettings.defaults.copyWith(weeklyGoal: 999999.99),
            onGoalChanged: (period, amount) {
              changedPeriod = period;
              changedAmount = amount;
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('edit-goal')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('goal-amount')),
      '123456.78',
    );
    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();

    expect(changedPeriod, EarningsGoalPeriod.week);
    expect(changedAmount, 123456.78);
    expect(tester.takeException(), isNull);
  });

  test('goal amounts survive settings serialization', () {
    final settings = FoxSettings.defaults.copyWith(
      weeklyGoal: 750,
      monthlyGoal: 3000,
      quarterlyGoal: 8500,
      yearlyGoal: 32000,
    );

    final restored = FoxSettings.fromJson(settings.toJson());

    expect(restored.weeklyGoal, 750);
    expect(restored.monthlyGoal, 3000);
    expect(restored.quarterlyGoal, 8500);
    expect(restored.yearlyGoal, 32000);
  });
}
