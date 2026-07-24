import 'verdict.dart';
import 'offer_summary.dart';

/// One completed watch session — from slide-to-live to stop. What the Home
/// "Last session" card shows: when, how long the watcher was on, and how the
/// offers it saw split by verdict.
class SessionSummary {
  final DateTime startedAt;
  final DateTime endedAt;
  final int good;
  final int ok;
  final int bad;

  const SessionSummary({
    required this.startedAt,
    required this.endedAt,
    this.good = 0,
    this.ok = 0,
    this.bad = 0,
  });

  int get total => good + ok + bad;
  Duration get duration => endedAt.difference(startedAt);

  /// Roll up a finished session from the offers logged while it ran.
  factory SessionSummary.from({
    required DateTime startedAt,
    required DateTime endedAt,
    required List<OfferSummary> offers,
  }) {
    var good = 0, ok = 0, bad = 0;
    for (final o in offers) {
      if (o.seenAt.isBefore(startedAt)) continue;
      switch (o.verdict) {
        case Verdict.good:
          good++;
        case Verdict.ok:
          ok++;
        case Verdict.bad:
          bad++;
        case Verdict.unknown:
          break;
      }
    }
    return SessionSummary(
      startedAt: startedAt,
      endedAt: endedAt,
      good: good,
      ok: ok,
      bad: bad,
    );
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'good': good,
    'ok': ok,
    'bad': bad,
  };

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.parse(j['endedAt'] as String),
    good: (j['good'] as num?)?.toInt() ?? 0,
    ok: (j['ok'] as num?)?.toInt() ?? 0,
    bad: (j['bad'] as num?)?.toInt() ?? 0,
  );
}
