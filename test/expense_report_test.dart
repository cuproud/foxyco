import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/expense_report.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/domain/vehicle_expense.dart';
import 'package:foxyco/ui/settings/income_expense_report.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';

void main() {
  final date = DateTime(2026, 9, 28);
  final offers = [
    OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.good,
      payout: 50,
      totalKm: 10,
      seenAt: date,
      outcome: OfferOutcome.completed,
      finalPayout: 55,
    ),
    OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.ok,
      payout: 20,
      totalKm: 10,
      seenAt: date,
      outcome: OfferOutcome.taken,
    ),
    OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.bad,
      payout: 30,
      totalKm: 10,
      seenAt: date,
      outcome: OfferOutcome.cancelled,
      finalPayout: 5,
    ),
    OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.good,
      payout: 100,
      totalKm: 10,
      seenAt: DateTime(2026, 10),
      outcome: OfferOutcome.taken,
    ),
  ];
  final expenses = [
    VehicleExpense(
      id: '1',
      category: 'Gas',
      description: 'Fuel',
      amount: 15,
      date: date,
    ),
  ];
  test('period boundaries, payout breakdown and bucket totals agree', () {
    final report = ExpenseReport(offers, expenses, ReportPeriod.month, date);
    expect(report.stats.recordedEarnings, 80);
    expect(report.stats.confirmedEarnings, 60);
    expect(report.stats.estimatedEarnings, 20);
    expect(report.balance, 65);
    expect(report.categories['Gas'], 15);
    expect(report.incomePoints.reduce((a, b) => a + b), 80);
    expect(report.expensePoints.reduce((a, b) => a + b), 15);
    final week = ExpenseReport(offers, expenses, ReportPeriod.week, date);
    expect(week.start, DateTime(2026, 9, 28));
    expect(week.end, DateTime(2026, 10, 5));
    expect(week.incomePoints, [80, 0, 0, 100, 0, 0, 0]);
    expect(ReportPeriod.week.move(date, -1), DateTime(2026, 9, 21));
    expect(
      ReportPeriod.week.move(DateTime(2026, 11, 1), 1),
      DateTime(2026, 11, 2),
    );
    expect(ReportPeriod.quarter.start(date), DateTime(2026, 7));
    expect(ReportPeriod.year.start(date), DateTime(2026));
    expect(
      ExpenseReport(
        [],
        [],
        ReportPeriod.month,
        DateTime(2024, 2),
      ).incomePoints.length,
      29,
    );
    expect(
      ExpenseReport(
        offers,
        expenses,
        ReportPeriod.year,
        date,
      ).stats.recordedEarnings,
      180,
    );
  });
  testWidgets('mobile report supports selectors, navigation, swipe and add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var added = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IncomeExpenseReport(
                offers: offers,
                expenses: expenses,
                currency: '\$',
                initialDate: date,
                onAdd: () => added = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('No last week income'), findsOneWidget);
    expect(find.byKey(const Key('expense-graph-toggle')), findsNothing);
    expect(find.text('\$100.00'), findsWidgets);
    final firstSparkleFrame = tester
        .widget<CustomPaint>(find.byKey(const Key('selected-bar-sparkles')))
        .painter!;
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump(const Duration(milliseconds: 400));
    final nextSparkleFrame = tester
        .widget<CustomPaint>(find.byKey(const Key('selected-bar-sparkles')))
        .painter!;
    expect(nextSparkleFrame.shouldRepaint(firstSparkleFrame), isTrue);
    await tester.tap(find.byKey(const ValueKey('income-bar-0')));
    await tester.pump();
    expect(find.byKey(const Key('selected-bar-sparkles')), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.text('\$80.00'), findsWidgets);
    expect(find.byKey(const Key('selected-bar-sparkles')), findsOneWidget);
    final selectedAmount = tester.getCenter(
      find.byKey(const Key('selected-income-amount')),
    );
    final selectedBar = tester.getCenter(
      find.byKey(const ValueKey('income-bar-0')),
    );
    expect((selectedAmount.dx - selectedBar.dx).abs(), lessThan(40));
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('No last month income'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('\$80.00'), findsWidgets);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.textContaining('CA\$'), findsNothing);
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('income-expenses-graph')),
      const Offset(-180, 0),
      700,
    );
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();
    expect(find.text('No last quarter income'), findsOneWidget);
    expect(find.text('Q3 · 2026'), findsOneWidget);
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('No last year income'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next period'));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);
    await tester.ensureVisible(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    expect(added, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps selected-bar reflections still', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: IncomeExpenseReport(
                offers: offers,
                expenses: expenses,
                currency: '\$',
                initialDate: date,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final first = tester
        .widget<CustomPaint>(find.byKey(const Key('selected-bar-sparkles')))
        .painter!;
    await tester.pump(const Duration(seconds: 3));
    final later = tester
        .widget<CustomPaint>(find.byKey(const Key('selected-bar-sparkles')))
        .painter!;
    expect(later.shouldRepaint(first), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('weekly income change compares with the previous week', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prior = OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.good,
      payout: 40,
      finalPayout: 40,
      totalKm: 10,
      seenAt: DateTime(2026, 9, 21),
      outcome: OfferOutcome.completed,
    );
    final current = OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.good,
      payout: 80,
      finalPayout: 80,
      totalKm: 10,
      seenAt: DateTime(2026, 9, 28),
      outcome: OfferOutcome.completed,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncomeExpenseReport(
              offers: [prior, current],
              expenses: const [],
              currency: '\$',
              initialDate: DateTime(2026, 9, 28),
              onAdd: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('↗ +100.0%'), findsOneWidget);
    expect(find.text('vs last week'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('No last week income'), findsOneWidget);
  });
  testWidgets(
    'report supports both themes and enlarged text on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('fonts/Inter.ttf'));
      await font.load();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => FoxColors.apply(FoxPalette.dark));
      for (final palette in [FoxPalette.light, FoxPalette.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.of(palette),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: IncomeExpenseReport(
                    offers: offers,
                    expenses: expenses,
                    currency: '\$',
                    initialDate: date,
                    onAdd: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const Key('income-expenses-graph')),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((card.decoration! as BoxDecoration).gradient!.colors, [
          palette.cardTop,
          palette.cardBottom,
        ]);
        await tester.tap(find.byTooltip('Previous period'));
        await tester.pumpAndSettle();
        expect(find.text('No recorded income in this period'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
