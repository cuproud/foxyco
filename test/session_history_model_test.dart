import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_currency.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/scoring_snapshot.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/parser/parser_registry.dart';
import 'package:foxyco/domain/verdict.dart';

OfferSummary _offer(
  OfferOutcome outcome, {
  double payout = 20,
  DateTime? seenAt,
}) => OfferSummary(
  platform: GigPlatform.uber,
  verdict: Verdict.good,
  payout: payout,
  pickupKm: 1,
  totalKm: 10,
  totalMinutes: 30,
  seenAt: seenAt ?? DateTime(2026, 8, 18, 10),
  outcome: outcome,
  scoringSnapshot: ScoringSnapshot.fromSettings(FoxSettings.defaults),
);

void main() {
  test(
    'historical scoring snapshot round-trips independently of live rules',
    () {
      final offer = _offer(OfferOutcome.unknown);
      final restored = OfferSummary.fromJson(offer.toJson());

      expect(restored.scoringSnapshot, isNotNull);
      expect(restored.scoringSnapshot!.goodPerKm, 1.5);
      expect(restored.scoringSnapshot!.distanceUnit, DistanceUnit.kilometres);
      expect(restored.scoringSnapshot!.currency, AppCurrency.cad);
    },
  );

  test('manual outcome correction preserves the detected outcome', () {
    final detected = _offer(OfferOutcome.taken).withOutcome(OfferOutcome.taken);
    final corrected = detected.withOutcome(
      OfferOutcome.cancelled,
      manual: true,
    );

    expect(corrected.outcome, OfferOutcome.cancelled);
    expect(corrected.outcomeIsManual, isTrue);
    expect(corrected.detectedOutcome, OfferOutcome.taken);
  });

  test('session earnings only estimate completed offers', () {
    final start = DateTime(2026, 8, 18, 10);
    final session = SessionSummary.from(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 2)),
      offers: [
        _offer(OfferOutcome.completed, payout: 25, seenAt: start),
        _offer(OfferOutcome.taken, payout: 40, seenAt: start),
        _offer(OfferOutcome.cancelled, payout: 30, seenAt: start),
        _offer(OfferOutcome.missed, payout: 10, seenAt: start),
      ],
    );

    expect(session.estimatedEarnings, 25);
    expect(session.completed, 1);
    expect(session.cancelled, 1);
    expect(session.declined, 1);
    expect(session.hourlyEarnings, 12.5);
  });

  test('manual actual session earnings do not alter captured offers', () {
    final offer = _offer(OfferOutcome.completed, payout: 25);
    final session = SessionSummary.from(
      startedAt: offer.seenAt,
      endedAt: offer.seenAt.add(const Duration(hours: 1)),
      offers: [offer],
    ).withActualEarnings(43.50);

    expect(session.earnings, 43.50);
    expect(session.actualEarningsIsManual, isTrue);
    expect(offer.payout, 25);
  });

  test('parser capability is narrower than platform metadata', () {
    expect(ParserRegistry.hasParser(GigPlatform.uber), isTrue);
    expect(ParserRegistry.hasParser(GigPlatform.uberEats), isFalse);
    expect(ParserRegistry.hasParser(GigPlatform.doorDash), isTrue);
    expect(ParserRegistry.hasParser(GigPlatform.instacart), isTrue);
    expect(FoxSettings.defaults.watches(GigPlatform.doorDash), isFalse);
    expect(FoxSettings.defaults.watches(GigPlatform.instacart), isFalse);
  });
}
