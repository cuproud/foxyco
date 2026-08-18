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

  test('session summary carries accepted count with legacy default', () {
    final session = SessionSummary.from(
      startedAt: DateTime(2026, 7, 16),
      endedAt: DateTime(2026, 7, 16, 1),
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
