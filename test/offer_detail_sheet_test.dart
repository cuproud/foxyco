import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/ui/history/offer_detail_sheet.dart';

/// The sheet used to be capped at 9/16 of the screen with unbounded content
/// inside it, so on a short viewport (or at a large text scale) the top of the
/// card was clipped and Flutter threw an overflow. It is scroll-controlled now.
void main() {
  final offer = OfferSummary(
    platform: GigPlatform.uber,
    verdict: Verdict.bad,
    payout: 17.01,
    totalKm: 26,
    pickupKm: 0.2,
    totalMinutes: 28,
    category: 'UberX Share Comfort',
    outcome: OfferOutcome.missed,
    seenAt: DateTime(2026, 7, 26, 19, 58),
  );

  Future<void> open(WidgetTester tester, [OfferSummary? selected]) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOfferDetail(context, selected ?? offer),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('short viewport: every line renders, nothing overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1400); // ~466 dp tall
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('CA\$17.01'), findsOne);
    expect(find.text('UberX Share Comfort'), findsOne); // not ellipsised away
    expect(find.text('PER KM'), findsOne);
    expect(find.text('TRIP RATE / HOUR'), findsOne);
    expect(find.text('TOTAL DISTANCE'), findsOne);
    expect(find.text('TOTAL TIME'), findsOne);
    expect(find.textContaining('saved scoring snapshot'), findsNothing);
    // Bottom of the card is reachable by scrolling, not cut off.
    await tester.drag(find.text('CA\$17.01'), const Offset(0, -300));
    await tester.pump();
    expect(find.text('Not taken'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text scale still lays out', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('CA\$17.01'), findsOne);
  });

  testWidgets('large text final earnings form keeps labels visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await open(tester, offer.withOutcome(OfferOutcome.taken));
    await tester.tap(find.text('Add final'));
    await tester.pumpAndSettle();

    expect(find.text('Earnings before tip'), findsOneWidget);
    expect(find.text('Tip'), findsOneWidget);
    expect(find.text('Toll reimbursement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows included tip and toll with net performance rate', (
    tester,
  ) async {
    await open(
      tester,
      OfferSummary(
        platform: GigPlatform.hopp,
        verdict: Verdict.good,
        payout: 22.14,
        finalPayout: 38.34,
        tip: 5.19,
        tollReimbursement: 9.16,
        totalKm: 20,
        totalMinutes: 60,
        outcome: OfferOutcome.completed,
        seenAt: DateTime(2026, 8, 31, 8),
      ),
    );

    expect(find.text(r'Tip CA$5.19'), findsOneWidget);
    expect(find.text(r'Toll CA$9.16'), findsOneWidget);
    expect(find.text(r'CA$1.46'), findsOneWidget);
    expect(find.text(r'CA$29.18'), findsOneWidget);
    expect(find.text('TRIP RATE / HOUR'), findsOneWidget);
  });
}
