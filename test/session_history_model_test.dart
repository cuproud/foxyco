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
  double? finalPayout,
  DateTime? seenAt,
}) => OfferSummary(
  platform: GigPlatform.uber,
  verdict: Verdict.good,
  payout: payout,
  finalPayout: finalPayout,
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

  test('session earnings estimate accepted and completed offers', () {
    final start = DateTime(2026, 8, 18, 10);
    final session = SessionSummary.from(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 2)),
      offers: [
        _offer(OfferOutcome.completed, payout: 25, seenAt: start),
        _offer(OfferOutcome.taken, payout: 40, seenAt: start),
        _offer(
          OfferOutcome.cancelled,
          payout: 30,
          finalPayout: 5,
          seenAt: start,
        ),
        _offer(OfferOutcome.missed, payout: 10, seenAt: start),
      ],
    );

    expect(session.estimatedEarnings, 70);
    expect(session.completed, 1);
    expect(session.cancelled, 1);
    expect(session.declined, 1);
    expect(session.hourlyEarnings, 35);
  });

  test('daily recap combines work blocks and keeps breaks out of duration', () {
    final day = DateTime(2026, 8, 18);
    final first = SessionSummary(
      startedAt: day.add(const Duration(hours: 7)),
      endedAt: day.add(const Duration(hours: 12)),
      good: 2,
      accepted: 1,
      declined: 1,
      estimatedEarnings: 42,
    );
    final second = SessionSummary(
      startedAt: day.add(const Duration(hours: 16)),
      endedAt: day.add(const Duration(hours: 20)),
      bad: 3,
      accepted: 2,
      estimatedEarnings: 68,
    );

    final recap = SessionDaySummary.recent([second, first]).single;

    expect(recap.duration, const Duration(hours: 9));
    expect(recap.earnings, 110);
    expect(recap.total, 5);
    expect(recap.accepted, 3);
    expect(recap.acceptanceRate, closeTo(0.75, 1e-9));
    expect(recap.hourlyEarnings, closeTo(110 / 9, 1e-9));
    expect(recap.startedAt, first.startedAt);
    expect(recap.endedAt, second.endedAt);
  });

  test('completed earnings prefer an entered final payout', () {
    final start = DateTime(2026, 8, 21, 15);
    final offer = OfferSummary(
      platform: GigPlatform.lyft,
      verdict: Verdict.ok,
      payout: 19.70,
      finalPayout: 22.26,
      totalKm: 14.1,
      totalMinutes: 43,
      seenAt: start.add(const Duration(minutes: 1)),
      outcome: OfferOutcome.completed,
    );

    final session = SessionSummary.from(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      offers: [offer],
    );

    expect(session.estimatedEarnings, 22.26);
    expect(session.bestPerKm, closeTo(22.26 / 14.1, 1e-9));
    expect(
      offer.verdict,
      Verdict.ok,
      reason: 'upfront verdict stays immutable',
    );
  });

  test('session rate excludes reimbursed toll but payout keeps it', () {
    final start = DateTime(2026, 8, 31, 8);
    final session = SessionSummary.from(
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      offers: [
        OfferSummary(
          platform: GigPlatform.hopp,
          verdict: Verdict.good,
          payout: 22.14,
          finalPayout: 38.34,
          tip: 5.19,
          tollReimbursement: 9.16,
          totalKm: 20,
          totalMinutes: 45,
          seenAt: start,
          outcome: OfferOutcome.completed,
        ),
      ],
    );

    expect(session.earnings, 38.34);
    expect(session.performanceEarnings, closeTo(29.18, 1e-9));
    expect(session.hourlyEarnings, closeTo(29.18, 1e-9));
    expect(
      SessionSummary.fromJson(session.toJson()).performanceEarnings,
      closeTo(29.18, 1e-9),
    );
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
    expect(ParserRegistry.hasParser(GigPlatform.skip), isTrue);
    expect(FoxSettings.defaults.watches(GigPlatform.doorDash), isFalse);
    expect(FoxSettings.defaults.watches(GigPlatform.instacart), isFalse);
    expect(FoxSettings.defaults.watches(GigPlatform.skip), isFalse);
  });
}
