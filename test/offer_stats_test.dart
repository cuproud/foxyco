import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/domain/offer_stats.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/domain/verdict.dart';

OfferSummary _o(
  Verdict v,
  double payout,
  double km, {
  int hour = 12,
  GigPlatform platform = GigPlatform.uber,
  OfferOutcome outcome = OfferOutcome.unknown,
}) => OfferSummary(
  platform: platform,
  verdict: v,
  payout: payout,
  totalKm: km,
  seenAt: DateTime(2026, 7, 16, hour, 5),
  outcome: outcome,
);

void main() {
  test('empty list → zeroed stats, no best/busiest', () {
    const s = OfferStats();
    expect(OfferStats.from(const []).total, s.total);
    expect(OfferStats.from(const []).best, isNull);
    expect(OfferStats.from(const []).busiestHour, isNull);
    expect(OfferStats.from(const []).goodAvgPerKm, 0);
  });

  test('counts split by verdict; unknown excluded from the split', () {
    final stats = OfferStats.from([
      _o(Verdict.good, 15, 10),
      _o(Verdict.good, 20, 10),
      _o(Verdict.ok, 11, 10),
      _o(Verdict.bad, 5, 10),
      _o(Verdict.unknown, 1, 1),
    ]);
    expect(stats.total, 5);
    expect(stats.good, 2);
    expect(stats.ok, 1);
    expect(stats.bad, 1);
  });

  test('accepted is counted separately from the verdict split', () {
    final stats = OfferStats.from([
      _o(Verdict.good, 15, 10, outcome: OfferOutcome.taken),
      _o(Verdict.bad, 5, 10, outcome: OfferOutcome.taken),
      _o(Verdict.ok, 10, 10),
    ]);
    expect(stats.total, 3);
    expect(stats.good + stats.ok + stats.bad, 3);
    expect(stats.accepted, 2);
  });

  test('performance totals include taken and completed offers', () {
    final stats = OfferStats.from([
      OfferSummary(
        platform: GigPlatform.uber,
        verdict: Verdict.good,
        payout: 20,
        totalKm: 10,
        totalMinutes: 30,
        seenAt: DateTime(2026, 7, 16, 12),
        outcome: OfferOutcome.taken,
      ),
      OfferSummary(
        platform: GigPlatform.lyft,
        verdict: Verdict.ok,
        payout: 15,
        finalPayout: 18,
        totalKm: 5,
        totalMinutes: 30,
        seenAt: DateTime(2026, 7, 16, 13),
        outcome: OfferOutcome.completed,
      ),
      _o(Verdict.bad, 50, 50),
    ]);

    expect(stats.acceptedEarnings, 38);
    expect(stats.acceptedPerformanceEarnings, 38);
    expect(stats.acceptedKm, 15);
    expect(stats.acceptedMinutes, 60);
    expect(stats.accepted, 2);
  });

  test('toll stays in received total but not performance earnings', () {
    final stats = OfferStats.from([
      OfferSummary(
        platform: GigPlatform.hopp,
        verdict: Verdict.good,
        payout: 22.14,
        finalPayout: 38.34,
        tollReimbursement: 9.16,
        totalKm: 20,
        totalMinutes: 60,
        seenAt: DateTime(2026, 8, 31, 8),
        outcome: OfferOutcome.completed,
      ),
    ]);

    expect(stats.acceptedEarnings, 38.34);
    expect(stats.acceptedPerformanceEarnings, closeTo(29.18, 1e-9));
    expect(stats.best!.effectivePricePerHour, closeTo(29.18, 1e-9));
  });

  test('session summary carries accepted count with legacy default', () {
    final session = SessionSummary.from(
      startedAt: DateTime(2026, 7, 16),
      endedAt: DateTime(2026, 7, 16, 13),
      offers: [_o(Verdict.good, 15, 10, outcome: OfferOutcome.taken)],
    );

    expect(session.accepted, 1);
    expect(SessionSummary.fromJson(session.toJson()).accepted, 1);
    expect(
      SessionSummary.fromJson({
        'startedAt': '2026-07-16T00:00:00.000',
        'endedAt': '2026-07-16T01:00:00.000',
      }).accepted,
      0,
    );
  });

  test('session summary tracks accepted trips missing a final payout', () {
    final session = SessionSummary.from(
      startedAt: DateTime(2026, 7, 16),
      endedAt: DateTime(2026, 7, 16, 13),
      offers: [
        _o(Verdict.good, 15, 10, outcome: OfferOutcome.taken),
        _o(Verdict.good, 20, 10, outcome: OfferOutcome.completed),
      ],
    );

    expect(session.accepted, 2);
    expect(session.missingFinalPayouts, 2);
    expect(SessionSummary.fromJson(session.toJson()).missingFinalPayouts, 2);
  });

  test('goodAvgPerKm averages GOOD offers only', () {
    final stats = OfferStats.from([
      _o(Verdict.good, 20, 10), // 2.00/km
      _o(Verdict.good, 10, 10), // 1.00/km
      _o(Verdict.bad, 90, 10), // 9.00/km — bad, must not skew the average
    ]);
    expect(stats.goodAvgPerKm, closeTo(1.50, 0.001));
  });

  test('goodAvgPerKm skips zero-km offers instead of averaging in a 0', () {
    final stats = OfferStats.from([
      _o(Verdict.good, 20, 10), // 2.00/km
      _o(Verdict.good, 20, 0), // km unknown → excluded
    ]);
    expect(stats.goodAvgPerKm, closeTo(2.00, 0.001));
  });

  test('best is the highest \$/km offer regardless of verdict', () {
    final best = _o(Verdict.ok, 30, 10, platform: GigPlatform.lyft);
    final stats = OfferStats.from([_o(Verdict.good, 15, 10), best]);
    expect(stats.best, same(best));
  });

  test('busiest hour wins by count, ties to the earlier hour', () {
    final stats = OfferStats.from([
      _o(Verdict.good, 10, 5, hour: 17),
      _o(Verdict.ok, 10, 5, hour: 17),
      _o(Verdict.bad, 10, 5, hour: 9),
      _o(Verdict.bad, 10, 5, hour: 9),
      _o(Verdict.ok, 10, 5, hour: 21),
    ]);
    expect(stats.busiestHour, 9); // 9 and 17 tie at 2 → earlier wins
  });
}
