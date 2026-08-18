import 'platform.dart';
import 'scoring_snapshot.dart';
import 'verdict.dart';

/// What happened to an offer after FoxyCo scored it — inferred from the screen
/// the app landed on when the card left, or corrected manually in History:
///   - the app returned to browse/home/map → the driver passed (declined or
///     let it time out) → [missed];
///   - the app moved to a non-browse screen (in-trip navigation) → the driver
///     took it → [taken].
/// Automatic values are heuristic (app switch / kill mid-card → [unknown]); a
/// manual correction is stored separately and wins over later inference.
enum OfferOutcome { unknown, taken, missed, cancelled, completed }

/// A scored offer as logged to the offer repository and shown on the dashboard
/// ("Last offer") and History. Display/persistence view of the richer
/// parse-time `Offer` model — flat, primitive, JSON-round-trippable.
class OfferSummary {
  final GigPlatform platform;
  final Verdict verdict;
  final double payout; // dollars
  final double bonus; // included in payout; 0 when absent/unknown
  final double pickupKm; // dead mileage to the rider; 0 when unknown
  final double totalKm; // pickup + dropoff
  final double totalMinutes; // pickup + trip; 0 when unknown
  final DateTime seenAt;
  final OfferOutcome outcome; // inferred take/pass — see [OfferOutcome]
  final bool outcomeIsManual;
  final OfferOutcome? detectedOutcome;
  final ScoringSnapshot? scoringSnapshot;

  /// Product tier / ride type ("UberX", "Comfort", "Radar match", …) or null.
  /// Display only — see [Offer.category].
  final String? category;
  final bool isQueued;
  final int deliveryCount;

  const OfferSummary({
    required this.platform,
    required this.verdict,
    required this.payout,
    this.bonus = 0,
    required this.totalKm,
    required this.seenAt,
    this.pickupKm = 0,
    this.totalMinutes = 0,
    this.outcome = OfferOutcome.unknown,
    this.outcomeIsManual = false,
    this.detectedOutcome,
    this.scoringSnapshot,
    this.category,
    this.isQueued = false,
    this.deliveryCount = 0,
  });

  /// Same CARD as [other]? Compares what the parser read off the screen, not
  /// when we read it — so one offer card seen twice reads as one offer.
  ///
  /// Labels that may arrive late (bonus, category, queued) are excluded too.
  /// The stable economics identify the live card; a confirmed card exit is what
  /// allows identical values to be recorded as a later offer.
  bool sameCardAs(OfferSummary other) =>
      platform == other.platform &&
      payout == other.payout &&
      totalKm == other.totalKm &&
      pickupKm == other.pickupKm &&
      totalMinutes == other.totalMinutes &&
      deliveryCount == other.deliveryCount;

  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;

  /// Dollars per hour; 0 when no time was parsed (UI hides it, no ∞).
  double get pricePerHour => totalMinutes > 0 ? payout / totalMinutes * 60 : 0;

  OfferSummary withOutcome(OfferOutcome o, {bool manual = false}) =>
      OfferSummary(
        platform: platform,
        verdict: verdict,
        payout: payout,
        bonus: bonus,
        pickupKm: pickupKm,
        totalKm: totalKm,
        totalMinutes: totalMinutes,
        seenAt: seenAt,
        outcome: o,
        outcomeIsManual: manual,
        detectedOutcome: manual ? detectedOutcome : (detectedOutcome ?? o),
        scoringSnapshot: scoringSnapshot,
        category: category,
        isQueued: isQueued,
        deliveryCount: deliveryCount,
      );

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'verdict': verdict.name,
    'payout': payout,
    'bonus': bonus,
    'pickupKm': pickupKm,
    'totalKm': totalKm,
    'totalMinutes': totalMinutes,
    'seenAt': seenAt.millisecondsSinceEpoch,
    'outcome': outcome.name,
    if (outcomeIsManual) 'outcomeIsManual': true,
    if (detectedOutcome != null) 'detectedOutcome': detectedOutcome!.name,
    if (scoringSnapshot != null) 'scoringSnapshot': scoringSnapshot!.toJson(),
    if (category != null) 'category': category,
    if (isQueued) 'isQueued': true,
    if (deliveryCount > 0) 'deliveryCount': deliveryCount,
  };

  factory OfferSummary.fromJson(Map<String, dynamic> j) => OfferSummary(
    platform:
        GigPlatform.values.where((p) => p.name == j['platform']).firstOrNull ??
        GigPlatform.uber,
    verdict:
        Verdict.values.where((v) => v.name == j['verdict']).firstOrNull ??
        Verdict.unknown,
    payout: (j['payout'] as num?)?.toDouble() ?? 0,
    bonus: (j['bonus'] as num?)?.toDouble() ?? 0,
    pickupKm: (j['pickupKm'] as num?)?.toDouble() ?? 0,
    totalKm: (j['totalKm'] as num?)?.toDouble() ?? 0,
    totalMinutes: (j['totalMinutes'] as num?)?.toDouble() ?? 0,
    seenAt: DateTime.fromMillisecondsSinceEpoch(
      (j['seenAt'] as num?)?.toInt() ?? 0,
    ),
    // Old blobs (pre-outcome) load as unknown.
    outcome:
        OfferOutcome.values.where((o) => o.name == j['outcome']).firstOrNull ??
        OfferOutcome.unknown,
    outcomeIsManual: j['outcomeIsManual'] == true,
    detectedOutcome: OfferOutcome.values
        .where((o) => o.name == j['detectedOutcome'])
        .firstOrNull,
    scoringSnapshot: j['scoringSnapshot'] is Map
        ? ScoringSnapshot.fromJson(
            Map<String, dynamic>.from(j['scoringSnapshot'] as Map),
          )
        : null,
    category: j['category'] is String ? j['category'] as String : null,
    isQueued: j['isQueued'] == true,
    deliveryCount: (j['deliveryCount'] as num?)?.toInt() ?? 0,
  );
}
