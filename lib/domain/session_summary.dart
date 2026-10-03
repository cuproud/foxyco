import 'dart:math' as math;

import 'offer_stats.dart';
import 'offer_summary.dart';
import 'platform.dart';
import 'verdict.dart';

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
  int get knownOutcomes => accepted + declined;
  double? get acceptanceRate =>
      knownOutcomes == 0 ? null : accepted / knownOutcomes;
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
      estimatedEarnings: stats.recordedEarnings,
      estimatedPerformanceEarnings: stats.recordedPerformanceEarnings,
      missingFinalPayouts: stats.missingFinalPayouts,
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

/// Finished watcher sessions combined by calendar day for the Home recap.
/// Duration adds active periods (breaks are excluded); the displayed time
/// range spans the first start through the final stop.
class SessionDaySummary {
  final DateTime date;
  final List<SessionSummary> sessions;
  final List<OfferSummary> manualOffers;

  const SessionDaySummary({
    required this.date,
    required this.sessions,
    this.manualOffers = const [],
  });

  bool get hasWatchSessions => sessions.isNotEmpty;
  bool _inSession(OfferSummary offer) => sessions.any(
    (session) =>
        !offer.seenAt.isBefore(session.startedAt) &&
        !offer.seenAt.isAfter(session.endedAt),
  );
  Iterable<OfferSummary> get _manualInSessions =>
      manualOffers.where(_inSession);
  Iterable<OfferSummary> get _manualOutsideSessions =>
      manualOffers.where((offer) => !_inSession(offer));
  int get manualJobs => manualOffers
      .where(
        (offer) =>
            offer.outcome == OfferOutcome.taken ||
            offer.outcome == OfferOutcome.completed,
      )
      .length;

  DateTime get startedAt => [
    ...sessions.map((session) => session.startedAt),
    ...manualOffers.map((offer) => offer.seenAt),
  ].reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get endedAt => [
    ...sessions.map((session) => session.endedAt),
    ...manualOffers.map((offer) => offer.seenAt),
  ].reduce((a, b) => a.isAfter(b) ? a : b);
  Duration get duration => sessions.fold(
    Duration.zero,
    (total, session) => total + session.duration,
  );
  int get total => math.max(
    0,
    sessions.fold(0, (total, session) => total + session.total) -
        _manualInSessions
            .where((offer) => offer.verdict != Verdict.unknown)
            .length,
  );
  int get good => math.max(
    0,
    sessions.fold(0, (total, session) => total + session.good) -
        _manualInSessions
            .where((offer) => offer.verdict == Verdict.good)
            .length,
  );
  int get ok => math.max(
    0,
    sessions.fold(0, (total, session) => total + session.ok) -
        _manualInSessions.where((offer) => offer.verdict == Verdict.ok).length,
  );
  int get bad => math.max(
    0,
    sessions.fold(0, (total, session) => total + session.bad) -
        _manualInSessions.where((offer) => offer.verdict == Verdict.bad).length,
  );
  int get accepted =>
      sessions.fold(0, (total, session) => total + session.accepted) +
      _manualOutsideSessions
          .where(
            (offer) =>
                offer.outcome == OfferOutcome.taken ||
                offer.outcome == OfferOutcome.completed,
          )
          .length;
  int get capturedAccepted => math.max(0, accepted - manualJobs);
  int get declined =>
      sessions.fold(0, (total, session) => total + session.declined);
  double get earnings =>
      sessions.fold(0.0, (total, session) => total + session.earnings) +
      OfferStats.from(_manualOutsideSessions.toList()).recordedEarnings;
  double get performanceEarnings =>
      sessions.fold(
        0.0,
        (total, session) => total + session.performanceEarnings,
      ) +
      OfferStats.from(
        _manualOutsideSessions.toList(),
      ).recordedPerformanceEarnings;
  double? get acceptanceRate => total == 0 ? null : capturedAccepted / total;
  double get recordedMinutes =>
      duration.inSeconds / 60 +
      _manualOutsideSessions
          .where(
            (offer) =>
                offer.outcome == OfferOutcome.taken ||
                offer.outcome == OfferOutcome.completed,
          )
          .fold(0.0, (total, offer) => total + offer.totalMinutes);
  double get hourlyEarnings =>
      recordedMinutes == 0 ? 0 : performanceEarnings / (recordedMinutes / 60);

  static List<SessionDaySummary> recent(
    List<SessionSummary> sessions, {
    List<OfferSummary> offers = const [],
    int limit = 3,
  }) {
    final byDay = <DateTime, List<SessionSummary>>{};
    final manualByDay = <DateTime, List<OfferSummary>>{};
    for (final session in sessions) {
      final date = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      byDay.putIfAbsent(date, () => []).add(session);
    }
    for (final offer in offers.where((offer) => offer.isManualEntry)) {
      final date = DateTime(
        offer.seenAt.year,
        offer.seenAt.month,
        offer.seenAt.day,
      );
      manualByDay.putIfAbsent(date, () => []).add(offer);
    }
    final days =
        {...byDay.keys, ...manualByDay.keys}
            .map(
              (date) => SessionDaySummary(
                date: date,
                sessions: byDay[date] ?? const [],
                manualOffers: manualByDay[date] ?? const [],
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return days.take(limit).toList();
  }
}
