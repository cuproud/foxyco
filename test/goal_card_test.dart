import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/ui/home/goal_card.dart';
import 'package:foxyco/ui/history/history_intent.dart';

void main() {
  testWidgets('goal matches History accepted earnings and switches periods', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 9, 19, 12);
    EarningsGoalPeriod? viewedPeriod;
    OfferSummary offer(
      double payout,
      OfferOutcome outcome, {
      double? finalPayout,
      double tollReimbursement = 0,
    }) => OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.good,
      payout: payout,
      finalPayout: finalPayout,
      tollReimbursement: tollReimbursement,
      totalKm: 10,
      seenAt: DateTime(2026, 9, 18, 18),
      outcome: outcome,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalCard(
            offers: [
              offer(100, OfferOutcome.taken),
              offer(
                200,
                OfferOutcome.completed,
                finalPayout: 260,
                tollReimbursement: 50,
              ),
              offer(300, OfferOutcome.cancelled, finalPayout: 40),
              offer(500, OfferOutcome.missed),
            ],
            settings: FoxSettings.defaults,
            now: now,
            onViewHistory: (period) => viewedPeriod = period,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly goal'), findsOneWidget);
    expect(find.textContaining(r'$400'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goal-month')));
    await tester.pumpAndSettle();

    expect(find.text('Monthly goal'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goal-view-history')));
    expect(viewedPeriod, EarningsGoalPeriod.month);
  });

  test('goal periods and History intents use the same calendar range', () {
    final (start, end) = EarningsGoalPeriod.quarter.dateRange(
      DateTime(2026, 9, 20),
    );

    expect(start, DateTime(2026, 7));
    expect(end, DateTime(2026, 10));
    expect(
      HistoryIntent.forGoal(EarningsGoalPeriod.quarter).goalPeriod,
      EarningsGoalPeriod.quarter,
    );
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
