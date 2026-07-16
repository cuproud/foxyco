import 'offer_summary.dart';
import 'verdict.dart';

/// Rollup over a set of logged offers (docs/ROADMAP "shift summary") — the
/// numbers a driver actually asks after a shift: how many offers, how they
/// split, what the worthwhile ones paid per km, and which hour was hottest.
///
/// Pure Dart, computed from whatever slice the caller passes (History hands it
/// the range+app-filtered list, so the card always matches the filters).
class OfferStats {
  final int total;
  final int good;
  final int ok;
  final int bad;

  /// Mean $/km across GOOD offers only — "what did the offers worth taking
  /// pay?". 0 when there were no good offers (UI shows a dash).
  final double goodAvgPerKm;

  /// The single highest-$/km offer seen, null when [total] is 0.
  final OfferSummary? best;

  /// Hour of day (0–23) with the most offers, null when [total] is 0. Ties go
  /// to the earlier hour.
  final int? busiestHour;

  const OfferStats({
    this.total = 0,
    this.good = 0,
    this.ok = 0,
    this.bad = 0,
    this.goodAvgPerKm = 0,
    this.best,
    this.busiestHour,
  });

  static OfferStats from(List<OfferSummary> offers) {
    if (offers.isEmpty) return const OfferStats();

    var good = 0, ok = 0, bad = 0;
    var goodPerKmSum = 0.0;
    var goodPerKmCount = 0;
    OfferSummary? best;
    final byHour = <int, int>{};

    for (final o in offers) {
      switch (o.verdict) {
        case Verdict.good:
          good++;
          if (o.pricePerKm > 0) {
            goodPerKmSum += o.pricePerKm;
            goodPerKmCount++;
          }
        case Verdict.ok:
          ok++;
        case Verdict.bad:
          bad++;
        case Verdict.unknown:
          break;
      }
      if (best == null || o.pricePerKm > best.pricePerKm) best = o;
      byHour.update(o.seenAt.hour, (n) => n + 1, ifAbsent: () => 1);
    }

    int? busiest;
    var busiestCount = 0;
    for (var h = 0; h < 24; h++) {
      final n = byHour[h] ?? 0;
      if (n > busiestCount) {
        busiest = h;
        busiestCount = n;
      }
    }

    return OfferStats(
      total: offers.length,
      good: good,
      ok: ok,
      bad: bad,
      goodAvgPerKm: goodPerKmCount == 0 ? 0 : goodPerKmSum / goodPerKmCount,
      best: best,
      busiestHour: busiest,
    );
  }
}
