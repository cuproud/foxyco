import 'offer_stats.dart';
import 'offer_summary.dart';

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
    this.bestPerKm = 0,
    this.goodAvgPerKm = 0,
    this.busiestHour,
  });

  int get total => good + ok + bad;
  Duration get duration => endedAt.difference(startedAt);

  /// A mis-slide: went live and stopped again within a minute, having seen
  /// nothing. Recording these buried a real 3h shift under an empty 0m card
  /// (device 2026-07-24), so the log drops them.
  bool get isTrivial => total == 0 && duration.inSeconds < 60;

  /// Roll up a finished session from the offers logged while it ran.
  factory SessionSummary.from({
    required DateTime startedAt,
    required DateTime endedAt,
    required List<OfferSummary> offers,
  }) {
    final stats = OfferStats.from(
      offers.where((o) => !o.seenAt.isBefore(startedAt)).toList(),
    );
    return SessionSummary(
      startedAt: startedAt,
      endedAt: endedAt,
      good: stats.good,
      ok: stats.ok,
      bad: stats.bad,
      accepted: stats.accepted,
      bestPerKm: stats.best?.pricePerKm ?? 0,
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
    bestPerKm: (j['bestPerKm'] as num?)?.toDouble() ?? 0,
    goodAvgPerKm: (j['goodAvgPerKm'] as num?)?.toDouble() ?? 0,
    busiestHour: (j['busiestHour'] as num?)?.toInt(),
  );
}
