import 'offer_stats.dart';
import 'offer_summary.dart';
import 'platform.dart';

/// One completed watch session — from slide-to-live to stop. What the Home
/// "Last session" card shows: when, how long the watcher was on, how the offers
/// it saw split by verdict, and the same three headline stats the shift-recap
/// sheet reports (best $/km, good average, busiest hour) so the card can show
/// a recap long after the sheet is gone.
class SessionSummary {
  final DateTime startedAt;
  final DateTime endedAt;
  final int good;
  final int ok;
  final int bad;
  final int accepted;
  final int completed;
  final int cancelled;
  final int declined;
  final int unknown;
  final double estimatedEarnings;
  final double estimatedPerformanceEarnings;
  final int missingFinalPayouts;
  final double? actualEarnings;
  final bool actualEarningsIsManual;
  final Set<GigPlatform> platforms;

  /// Highest $/km seen this session; 0 when nothing scored (UI shows a dash).
  final double bestPerKm;

  /// Mean $/km across GOOD offers only; 0 when there were none.
  final double goodAvgPerKm;

  /// Hour of day (0–23) that saw the most offers, null when none did.
  final int? busiestHour;

  const SessionSummary({
    required this.startedAt,
    required this.endedAt,
    this.good = 0,
    this.ok = 0,
    this.bad = 0,
    this.accepted = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.declined = 0,
    this.unknown = 0,
    this.estimatedEarnings = 0,
    double? estimatedPerformanceEarnings,
    this.missingFinalPayouts = 0,
    this.actualEarnings,
    this.actualEarningsIsManual = false,
    this.platforms = const {},
    this.bestPerKm = 0,
    this.goodAvgPerKm = 0,
    this.busiestHour,
  }) : estimatedPerformanceEarnings =
           estimatedPerformanceEarnings ?? estimatedEarnings;

  int get total => good + ok + bad;
  Duration get duration => endedAt.difference(startedAt);
  double get earnings => actualEarnings ?? estimatedEarnings;
  double get performanceEarnings =>
      actualEarnings ?? estimatedPerformanceEarnings;
  bool get hasActualEarnings => actualEarnings != null;
  double get hourlyEarnings => duration.inMinutes > 0
      ? performanceEarnings / (duration.inMinutes / 60)
      : 0;

  /// A mis-slide: went live and stopped again within a minute, having seen
  /// nothing. Recording these buried a real 3h shift under an empty 0m card
  /// (device 2026-07-24), so the log drops them.
  bool get isTrivial => total == 0 && duration.inSeconds < 60;

  SessionSummary withActualEarnings(double? value) => SessionSummary(
    startedAt: startedAt,
    endedAt: endedAt,
    good: good,
    ok: ok,
    bad: bad,
    accepted: accepted,
    completed: completed,
    cancelled: cancelled,
    declined: declined,
    unknown: unknown,
    estimatedEarnings: estimatedEarnings,
    estimatedPerformanceEarnings: estimatedPerformanceEarnings,
    missingFinalPayouts: missingFinalPayouts,
    actualEarnings: value,
    actualEarningsIsManual: value != null,
    platforms: platforms,
    bestPerKm: bestPerKm,
    goodAvgPerKm: goodAvgPerKm,
    busiestHour: busiestHour,
  );

  /// Roll up a finished session from the offers logged while it ran.
  factory SessionSummary.from({
    required DateTime startedAt,
    required DateTime endedAt,
    required List<OfferSummary> offers,
  }) {
    final sessionOffers = offers
        .where(
          (o) => !o.seenAt.isBefore(startedAt) && !o.seenAt.isAfter(endedAt),
        )
        .toList();
    final stats = OfferStats.from(sessionOffers);
    final completed = sessionOffers
        .where((o) => o.outcome == OfferOutcome.completed)
        .toList();
    final earningOffers = sessionOffers.where(
      (o) =>
          o.outcome == OfferOutcome.taken ||
          o.outcome == OfferOutcome.completed,
    );
    return SessionSummary(
      startedAt: startedAt,
      endedAt: endedAt,
      good: stats.good,
      ok: stats.ok,
      bad: stats.bad,
      accepted: stats.accepted,
      completed: completed.length,
      cancelled: sessionOffers
          .where((o) => o.outcome == OfferOutcome.cancelled)
          .length,
      declined: sessionOffers
          .where((o) => o.outcome == OfferOutcome.missed)
          .length,
      unknown: sessionOffers
          .where((o) => o.outcome == OfferOutcome.unknown)
          .length,
      estimatedEarnings: earningOffers.fold(
        0.0,
        (sum, o) => sum + o.effectivePayout,
      ),
      estimatedPerformanceEarnings: earningOffers.fold<double>(
        0.0,
        (sum, o) => sum + o.performancePayout,
      ),
      missingFinalPayouts: earningOffers
          .where((o) => o.finalPayout == null)
          .length,
      platforms: sessionOffers.map((o) => o.platform).toSet(),
      bestPerKm: stats.best?.effectivePricePerKm ?? 0,
      goodAvgPerKm: stats.goodAvgPerKm,
      busiestHour: stats.busiestHour,
    );
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'good': good,
    'ok': ok,
    'bad': bad,
    'accepted': accepted,
    'completed': completed,
    'cancelled': cancelled,
    'declined': declined,
    'unknown': unknown,
    'estimatedEarnings': estimatedEarnings,
    'estimatedPerformanceEarnings': estimatedPerformanceEarnings,
    'missingFinalPayouts': missingFinalPayouts,
    if (actualEarnings != null) 'actualEarnings': actualEarnings,
    if (actualEarningsIsManual) 'actualEarningsIsManual': true,
    'platforms': platforms.map((p) => p.name).toList(),
    'bestPerKm': bestPerKm,
    'goodAvgPerKm': goodAvgPerKm,
    'busiestHour': busiestHour,
  };

  /// Sessions saved before the stats fields existed simply read 0/null and
  /// render dashes in the tiles.
  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.parse(j['endedAt'] as String),
    good: (j['good'] as num?)?.toInt() ?? 0,
    ok: (j['ok'] as num?)?.toInt() ?? 0,
    bad: (j['bad'] as num?)?.toInt() ?? 0,
    // Older sessions did not persist acceptance outcomes.
    accepted: (j['accepted'] as num?)?.toInt() ?? 0,
    completed: (j['completed'] as num?)?.toInt() ?? 0,
    cancelled: (j['cancelled'] as num?)?.toInt() ?? 0,
    declined: (j['declined'] as num?)?.toInt() ?? 0,
    unknown: (j['unknown'] as num?)?.toInt() ?? 0,
    estimatedEarnings: (j['estimatedEarnings'] as num?)?.toDouble() ?? 0,
    estimatedPerformanceEarnings: (j['estimatedPerformanceEarnings'] as num?)
        ?.toDouble(),
    missingFinalPayouts: (j['missingFinalPayouts'] as num?)?.toInt() ?? 0,
    actualEarnings: (j['actualEarnings'] as num?)?.toDouble(),
    actualEarningsIsManual: j['actualEarningsIsManual'] == true,
    platforms:
        (j['platforms'] as List<dynamic>?)
            ?.map((name) => GigPlatform.values.where((p) => p.name == name))
            .expand((items) => items)
            .toSet() ??
        const {},
    bestPerKm: (j['bestPerKm'] as num?)?.toDouble() ?? 0,
    goodAvgPerKm: (j['goodAvgPerKm'] as num?)?.toDouble() ?? 0,
    busiestHour: (j['busiestHour'] as num?)?.toInt(),
  );
}
