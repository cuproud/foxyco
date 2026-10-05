import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:foxyco/ui/history/history_screen.dart';
import 'package:foxyco/ui/history/history_intent.dart';
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

class _FixedSettings extends SettingsController {
  _FixedSettings(this.settings);
  final FoxSettings settings;
  @override
  FoxSettings build() => settings;
}

Widget _themedApp(
  List<OfferSummary> offers,
  FoxPalette palette, {
  DistanceUnit unit = DistanceUnit.kilometres,
  double scale = 1,
}) {
  final theme = AppTheme.of(palette);
  return ProviderScope(
    overrides: [
      offerLogProvider.overrideWith(() => _FixedLog(offers)),
      settingsProvider.overrideWith(
        () => _FixedSettings(FoxSettings.defaults.copyWith(distanceUnit: unit)),
      ),
    ],
    child: MaterialApp(
      builder: scale == 1
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
      theme: theme,
      home: const Scaffold(body: HistoryScreen()),
    ),
  );
}

void main() {
  testWidgets('rate units fit small screens and enlarged text in both themes', (
    tester,
  ) async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('fonts/Inter.ttf'));
    await font.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => FoxColors.apply(FoxPalette.dark));
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 900);
      for (final palette in [FoxPalette.light, FoxPalette.dark]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final unit in DistanceUnit.values) {
            await tester.pumpWidget(
              _themedApp(
                [
                  _offer(
                    DateTime.now(),
                    payout: 123,
                    outcome: OfferOutcome.taken,
                  ),
                ],
                palette,
                unit: unit,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            final strip = find.byKey(const ValueKey('history-rate-stats'));
            await tester.ensureVisible(strip);
            await tester.pumpAndSettle();
            final texts = find.descendant(
              of: strip,
              matching: find.byType(Text),
            );
            expect(
              tester
                  .widgetList<Text>(texts)
                  .where(
                    (t) => t.data?.endsWith('/${unit.shortLabel}') == true,
                  ),
              hasLength(2),
            );
            for (final element in texts.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '${(element.widget as Text).data} at $width/$scale',
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    }
  });

  testWidgets('filter groups do not inherit repeated phone inset padding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _themedApp([_offer(DateTime.now())], FoxPalette.light),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    for (final grid in tester.widgetList<GridView>(find.byType(GridView))) {
      expect(grid.padding, EdgeInsets.zero);
      expect(grid.primary, isFalse);
    }
    final platformGrid = find.byType(GridView).first;
    final verdict = find.text('3. Verdict');
    expect(
      tester.getTopLeft(verdict).dy - tester.getBottomLeft(platformGrid).dy,
      closeTo(4, .1),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('history-outcome-needsReview')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
      expect(
        find.image(const AssetImage('assets/history/hunt.webp')),
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

  testWidgets('performance explains when no offers were accepted', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_offer(DateTime.now())]));
    await tester.pumpAndSettle();

    expect(find.text('No recorded payouts'), findsOneWidget);
  });

  testWidgets('performance keeps payouts and drops the tiny breakdown', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _app([
        _offer(
          now,
          outcome: OfferOutcome.completed,
          payout: 20,
          finalPayout: 25,
        ),
        _offer(now, outcome: OfferOutcome.taken, payout: 20),
        _offer(
          now,
          outcome: OfferOutcome.cancelled,
          payout: 30,
          finalPayout: 5,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-performance-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Tracked payouts'), findsOneWidget);
    expect(find.text(r'$50.00'), findsOneWidget);
    expect(
      find.text(r'$30.00 final · $20.00 estimated · 1 need update'),
      findsNothing,
    );
  });

  testWidgets('recorded cancellation fee has a distinct theme-aware color', (
    tester,
  ) async {
    addTearDown(() => FoxColors.apply(FoxPalette.dark));
    final offer = _offer(
      DateTime.now(),
      platform: GigPlatform.lyft,
      outcome: OfferOutcome.cancelled,
      payout: 23.03,
      finalPayout: 2.26,
    );
    for (final palette in [FoxPalette.light, FoxPalette.dark]) {
      await tester.pumpWidget(_themedApp([offer], palette));
      await tester.pumpAndSettle();
      final card = find.byKey(
        ValueKey('history-offer-${offer.seenAt.microsecondsSinceEpoch}'),
      );
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final amount = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('CA\$2.26')),
      );
      expect(amount.style!.color, FoxColors.feeText);
      expect(amount.style!.color, isNot(FoxColors.brandText));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'goal intent shows only payouts contributing this calendar week',
    (tester) async {
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final offers = [
        _offer(start, outcome: OfferOutcome.completed, finalPayout: 25),
        _offer(
          start.add(const Duration(hours: 1)),
          outcome: OfferOutcome.cancelled,
          finalPayout: 5,
        ),
        _offer(start, outcome: OfferOutcome.missed),
        _offer(
          start.subtract(const Duration(days: 1)),
          outcome: OfferOutcome.completed,
          finalPayout: 50,
        ),
      ];
      final container = ProviderContainer(
        overrides: [offerLogProvider.overrideWith(() => _FixedLog(offers))],
      );
      addTearDown(container.dispose);
      container
          .read(pendingHistoryIntentProvider.notifier)
          .open(HistoryIntent.goalWeek);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 this week'), findsOneWidget);
      expect(find.textContaining('This week · Goal payouts'), findsOneWidget);
    },
  );

  testWidgets('offer card keeps compact content and footer aligned', (
    tester,
  ) async {
    final offer = _offer(DateTime.now());
    await tester.pumpWidget(_app([offer]));
    await tester.pumpAndSettle();

    final card = find.byKey(
      ValueKey('history-offer-${offer.seenAt.microsecondsSinceEpoch}'),
    );
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    Finder inCard(Finder matching) =>
        find.descendant(of: card, matching: matching);

    expect(inCard(find.text('GOOD')), findsOneWidget);
    expect(inCard(find.text('Unknown')), findsOneWidget);
    expect(inCard(find.text('10.0 km')), findsOneWidget);
    expect(inCard(find.text(r'$2.00/km')), findsOneWidget);
    expect(inCard(find.textContaining(r'CA$2.00/km')), findsNothing);

    final metricIcons = [
      inCard(find.byIcon(Icons.location_on_rounded)),
      inCard(find.byIcon(Icons.speed_rounded)),
      inCard(find.byIcon(Icons.schedule_rounded)),
    ];
    final baseline = tester.getCenter(metricIcons.first).dy;
    for (final icon in metricIcons.skip(1)) {
      expect(tester.getCenter(icon).dy, closeTo(baseline, 1));
    }
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
    final acceptedFilterAgain = find.byKey(
      const ValueKey('history-outcome-accepted'),
    );
    await tester.ensureVisible(acceptedFilterAgain);
    await tester.pumpAndSettle();
    await tester.tap(acceptedFilterAgain);
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
    final acceptedFilter = find.byKey(
      const ValueKey('history-outcome-accepted'),
    );
    await tester.ensureVisible(acceptedFilter);
    await tester.pumpAndSettle();
    await tester.tap(acceptedFilter);
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

  testWidgets('marking a ride cancelled offers fee entry immediately', (
    tester,
  ) async {
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
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled').last);
    await tester.pumpAndSettle();
    expect(find.text('Cancellation fee'), findsOneWidget);
    expect(find.byKey(const Key('cancellation-fee')), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets(
    'saving a cancellation fee keeps History open and records the fee',
    (tester) async {
      final offer = _offer(DateTime.now(), outcome: OfferOutcome.unknown);
      final container = ProviderContainer(
        overrides: [
          offerLogProvider.overrideWith(() => _FixedLog([offer])),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final status = find.byKey(
        ValueKey('offer_outcome_${offer.seenAt.microsecondsSinceEpoch}'),
      );
      await tester.scrollUntilVisible(
        status,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cancellation-fee')), '5.25');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final saved = container.read(offerLogProvider).single;
      expect(saved.outcome, OfferOutcome.cancelled);
      expect(saved.finalPayout, 5.25);
      expect(find.byType(HistoryScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

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
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_by_hour')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('history_by_hour')), findsOneWidget);
    final byHour = tester.widget<Container>(
      find.byKey(const Key('history_by_hour')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_by_app')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('history_by_app')), findsOneWidget);
    expect((byHour.decoration! as BoxDecoration).color, FoxColors.bgSurface);
    final byApp = tester.widget<Container>(
      find.byKey(const Key('history_by_app')),
    );
    expect((byApp.decoration! as BoxDecoration).color, FoxColors.bgSurface);
  });

  testWidgets('four-digit app totals stay on one line', (tester) async {
    final now = DateTime.now();
    final offers = [
      for (var i = 0; i < 1000; i++)
        _offer(now.subtract(Duration(milliseconds: i))),
      _offer(now, platform: GigPlatform.lyft),
    ];
    await tester.pumpWidget(_app(offers));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('history_by_app')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final byApp = find.byKey(const Key('history_by_app'));
    expect(find.descendant(of: byApp, matching: find.text('1000')), findsOne);
    expect(tester.takeException(), isNull);
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

    expect(find.text(r'All platforms · CA$20+ fare · Today'), findsOneWidget);
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
    expect(find.text('4 today'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-good')))
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('history-summary-good')))
          .style
          ?.fontSize,
      15,
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
    await tester.tap(find.byKey(const Key('history-performance-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: summary, matching: find.text('Offers')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Accepted')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Of seen')),
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

    final acceptedOutcome = find.byKey(
      const ValueKey('history-outcome-accepted'),
    );
    await tester.ensureVisible(acceptedOutcome);
    await tester.pumpAndSettle();
    await tester.tap(acceptedOutcome);
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
      final performanceCard = tester.widget<Container>(
        find.byKey(const ValueKey('history-performance-card')),
      );
      final performanceBorder =
          (performanceCard.foregroundDecoration! as BoxDecoration).border!
              as Border;
      expect(
        performanceBorder.top.color,
        FoxColors.textPrimary.withValues(
          alpha: palette == FoxPalette.light ? 0.22 : 0.32,
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('history-performance-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('history-performance-earnings')),
            )
            .style
            ?.color,
        palette == FoxPalette.light
            ? FoxColors.brandFoxDeep
            : FoxColors.brandFox,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filter offers'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-filter-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
