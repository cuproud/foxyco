import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/ui/history/history_screen.dart';

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
  Verdict verdict = Verdict.good,
}) => OfferSummary(
  platform: GigPlatform.uber,
  verdict: verdict,
  payout: payout,
  totalKm: 10,
  seenAt: seenAt,
  outcome: outcome,
);

Widget _app(List<OfferSummary> offers) => ProviderScope(
  overrides: [offerLogProvider.overrideWith(() => _FixedLog(offers))],
  child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
);

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
    expect(find.text('Go live and let the fox hunt.'), findsOneWidget);
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
    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();

    expect(find.text('1 today'), findsOneWidget);
    expect(
      find.text('All platforms · Any fare · Today · Accepted'),
      findsOneWidget,
    );

    await tester.tap(find.text('Accepted'));
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

  testWidgets('filter summary follows the fare floor', (tester) async {
    await tester.pumpWidget(_app([_offer(DateTime.now())]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-top-toggle')));
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
      find.descendant(of: summary, matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('1 good  ·  1 ok  ·  2 bad'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('2 of 4 accepted')),
      findsOneWidget,
    );

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAD'));
    await tester.pumpAndSettle();
    expect(find.text('2 today'), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('0 good  ·  0 ok  ·  2 bad'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('1 of 2 accepted')),
      findsOneWidget,
    );

    await tester.tap(find.text('Accepted'));
    await tester.pumpAndSettle();
    expect(find.text('1 today'), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('0 good  ·  0 ok  ·  1 bad'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('1 of 1 accepted')),
      findsOneWidget,
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
    await tester.tap(find.text('Accepted'));
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
}
