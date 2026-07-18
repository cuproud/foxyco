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
}

OfferSummary _offer(DateTime seenAt) => OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.good,
      payout: 20,
      totalKm: 10,
      seenAt: seenAt,
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
      'show filtered count 0 + smart empty state', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final offers = List.generate(22, (_) => _offer(yesterday));
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();
    // Header: filtered count, NOT all-time 22.
    expect(find.text('0 today'), findsOneWidget);
    expect(find.text('22 offers'), findsNothing); // old broken header
    // Smart empty state names the hidden offers + offers a reset.
    expect(find.textContaining('22 offers outside these filters'),
        findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('22 all time'), findsOneWidget);
    expect(find.textContaining('outside these filters'), findsNothing);
  });

  testWidgets('truly empty log shows plain empty state, no Show all',
      (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsNothing);
    expect(find.textContaining('No offers'), findsOneWidget);
  });
}
