import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/ui/history/history_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';

class _FixedLog extends OfferLog {
  _FixedLog(this._offers);
  final List<OfferSummary> _offers;
  @override
  List<OfferSummary> build() => _offers;

  @override
  bool setOutcome(OfferSummary offer, OfferOutcome outcome) {
    final index = state.indexOf(offer);
    if (index < 0) return false;
    state = [
      ...state.take(index),
      offer.withOutcome(outcome, manual: true),
      ...state.skip(index + 1),
    ];
    return true;
  }
}

OfferSummary _offer(
  DateTime seenAt, {
  OfferOutcome outcome = OfferOutcome.unknown,
  double payout = 20,
  double? finalPayout,
  double bonus = 0,
  Verdict verdict = Verdict.good,
  GigPlatform platform = GigPlatform.uber,
}) => OfferSummary(
  platform: platform,
  verdict: verdict,
  payout: payout,
  finalPayout: finalPayout,
  bonus: bonus,
  totalKm: 10,
  seenAt: seenAt,
  outcome: outcome,
);

Widget _app(List<OfferSummary> offers) => ProviderScope(
  overrides: [offerLogProvider.overrideWith(() => _FixedLog(offers))],
  child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
);

Widget _themedApp(List<OfferSummary> offers, FoxPalette palette) {
  final theme = AppTheme.of(palette);
  return ProviderScope(
    overrides: [offerLogProvider.overrideWith(() => _FixedLog(offers))],
    child: MaterialApp(
      theme: theme,
      home: const Scaffold(body: HistoryScreen()),
    ),
  );
}

void main() {
  test('headerLabel names the filtered range (spec M6 §5.1)', () {
    expect(HistoryScreen.headerLabel(0, HistoryRange.today), '0 today');
    expect(HistoryScreen.headerLabel(5, HistoryRange.today), '5 today');
    expect(HistoryScreen.headerLabel(3, HistoryRange.week), '3 in 7 days');
    expect(HistoryScreen.headerLabel(9, HistoryRange.month), '9 in 30 days');
    expect(HistoryScreen.headerLabel(22, HistoryRange.all), '22 all time');
  });

  testWidgets(
    'the 22-offers-empty-list bug: yesterday-only offers on Today filter '
    'show filtered count 0 + smart empty state',
    (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final offers = List.generate(22, (_) => _offer(yesterday));
      await tester.pumpWidget(_app(offers));
      await tester.pumpAndSettle();
      // Header: filtered count, NOT all-time 22.
      expect(find.text('0 today'), findsOneWidget);
      expect(find.text('22 offers'), findsNothing); // old broken header
      // Smart empty state names the hidden offers + offers a reset.
      expect(
        find.textContaining('22 offers outside these filters'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(find.text('22 all time'), findsOneWidget);
      expect(find.textContaining('outside these filters'), findsNothing);
    },
  );

  testWidgets('truly empty log shows plain empty state, no Show all', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsNothing);
    expect(find.text('No offers yet'), findsOneWidget);
    expect(find.text('Go live to start recording offers.'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsNothing);
    expect(
      find.image(const AssetImage('assets/history/hunt.webp')),
      findsOneWidget,
    );
  });

  testWidgets('Accepted history filter excludes missed and unknown offers', (
    tester,
  ) async {
    final now = DateTime.now();
    final offers = [
      _offer(now, outcome: OfferOutcome.taken, payout: 21),
      _offer(now, outcome: OfferOutcome.missed, payout: 22),
      _offer(now, outcome: OfferOutcome.unknown, payout: 23),
    ];
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();

    expect(find.text('3 today'), findsOneWidget);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-done')));
    await tester.pumpAndSettle();

    expect(find.text('1 today'), findsOneWidget);
    expect(
      find.text('All platforms · Any fare · Today · Accepted'),
      findsOneWidget,
    );

    await tester.tap(find.text('Filters · 1 active'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('3 today'), findsOneWidget);
  });

  testWidgets('status pill manually corrects a History offer', (tester) async {
    final offer = _offer(DateTime.now(), outcome: OfferOutcome.unknown);
    await tester.pumpWidget(_app([offer]));
    await tester.pumpAndSettle();

    final status = find.byKey(
      ValueKey('offer_outcome_${offer.seenAt.microsecondsSinceEpoch}'),
    );
    await tester.scrollUntilVisible(
      status,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.text('Offer outcome'), findsOneWidget);
    await tester.tap(find.text('Accepted').last);
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('accepted status stays on one line in a narrow card', (
    tester,
  ) async {
    final offer = _offer(DateTime.now(), outcome: OfferOutcome.taken);
    await tester.pumpWidget(_app([offer]));
    await tester.pumpAndSettle();

    final status = find.byKey(
      ValueKey('offer_outcome_${offer.seenAt.microsecondsSinceEpoch}'),
    );
    await tester.scrollUntilVisible(
      status,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final label = find.descendant(of: status, matching: find.text('Accepted'));
    final text = tester.widget<Text>(label);
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
  });

  testWidgets('realized payout does not crush accepted offer details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app([
        _offer(
          DateTime.now(),
          outcome: OfferOutcome.taken,
          payout: 19.70,
          finalPayout: 22.06,
          bonus: 4.55,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('+CA\$4.55 bonus'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('CA\$22.06'), findsOneWidget);
    expect(find.text('from CA\$19.70'), findsOneWidget);
    expect(tester.getSize(find.text('+CA\$4.55 bonus')).height, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('three-digit payout keeps history details aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app([_offer(DateTime.now(), payout: 123.45, bonus: 12.34)]),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('CA\$123.45'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('+CA\$12.34 bonus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters use one All and fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app([_offer(DateTime.now())]));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('All platforms · Any fare · Today'), findsOneWidget);
    expect(find.text('All'), findsNothing);
    expect(find.text('APP'), findsNothing);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('All apps'), findsNothing);
    expect(find.text('All ratings'), findsNothing);
    expect(find.text('All trips'), findsNothing);
    await tester.ensureVisible(find.text('4. Outcome'));
    await tester.pumpAndSettle();
    final verdictBottom = tester.getBottomRight(find.text('BAD')).dy;
    final outcomeTop = tester.getTopLeft(find.text('4. Outcome')).dy;
    expect(outcomeTop - verdictBottom, lessThan(40));
    final firstLayoutError = tester.takeException();
    expect(
      firstLayoutError,
      isNull,
      reason: firstLayoutError is FlutterError
          ? firstLayoutError.toStringDeep()
          : '$firstLayoutError',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters always include all supported delivery apps', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_offer(DateTime.now())]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('DoorDash'), findsOneWidget);
    expect(find.text('Instacart'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('analytical cards use solid surfaces and clear the nav', (
    tester,
  ) async {
    final now = DateTime.now();
    final offers = [
      _offer(now, verdict: Verdict.good),
      _offer(now, verdict: Verdict.ok),
      _offer(now, verdict: Verdict.bad),
      _offer(now, verdict: Verdict.good, platform: GigPlatform.lyft),
    ];
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      isA<EdgeInsets>().having((p) => p.bottom, 'bottom', greaterThan(100)),
    );
    expect(find.byKey(const Key('history_by_hour')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_by_app')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('history_by_app')), findsOneWidget);
    final byHour = tester.widget<Container>(
      find.byKey(const Key('history_by_hour')),
    );
    expect((byHour.decoration! as BoxDecoration).color, FoxColors.bgSurface);
    final byApp = tester.widget<Container>(
      find.byKey(const Key('history_by_app')),
    );
    expect((byApp.decoration! as BoxDecoration).color, FoxColors.bgSurface);
  });

  testWidgets('back to top appears after a long scroll and returns home', (
    tester,
  ) async {
    final now = DateTime.now();
    final offers = List.generate(
      80,
      (index) => _offer(
        now.subtract(Duration(minutes: index)),
        payout: 20 + index.toDouble(),
      ),
    );
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('history_back_to_top')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history_back_to_top')), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history_back_to_top')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('history_back_to_top')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scrollable>(find.byType(Scrollable).first)
          .controller!
          .offset,
      0,
    );
    expect(find.byKey(const ValueKey('history_back_to_top')), findsNothing);
  });

  testWidgets('filter summary follows the fare floor', (tester) async {
    await tester.pumpWidget(_app([_offer(DateTime.now())]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('history-top-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-top-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-done')));
    await tester.pumpAndSettle();

    expect(find.text(r'All platforms · $20+ fare · Today'), findsOneWidget);
  });

  testWidgets('summary math follows verdict and Accepted filters', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _app([
        _offer(now, outcome: OfferOutcome.taken),
        _offer(now, verdict: Verdict.ok),
        _offer(now, verdict: Verdict.bad),
        _offer(now, verdict: Verdict.bad, outcome: OfferOutcome.taken),
      ]),
    );
    await tester.pumpAndSettle();

    final summary = find.byKey(const ValueKey('history-summary'));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-total')))
          .data,
      '4',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-good')))
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-ok')))
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-bad')))
          .data,
      '2',
    );
    expect(
      find.descendant(of: summary, matching: find.text('Peak offer time')),
      findsOneWidget,
    );

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAD'));
    await tester.pumpAndSettle();
    expect(find.text('2 today'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-total')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-good')))
          .data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-ok')))
          .data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-bad')))
          .data,
      '2',
    );

    await tester.ensureVisible(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('1 today'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-total')))
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-good')))
          .data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-ok')))
          .data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-bad')))
          .data,
      '1',
    );
  });

  testWidgets('Show all also resets the Accepted history filter', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(_app([_offer(now, outcome: OfferOutcome.missed)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('0 today'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(find.text('1 all time'), findsOneWidget);
  });

  for (final (name, palette) in [
    ('light', FoxPalette.light),
    ('dark', FoxPalette.dark),
  ]) {
    testWidgets('$name theme redesign fits a narrow, scaled screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _themedApp([
          _offer(DateTime.now(), outcome: OfferOutcome.taken),
          _offer(DateTime.now(), verdict: Verdict.ok),
        ], palette),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-summary')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filter offers'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-filter-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
