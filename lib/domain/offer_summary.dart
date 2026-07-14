import 'platform.dart';
import 'verdict.dart';

/// A scored offer as logged to the offer repository and shown on the dashboard
/// ("Last offer") and History. Display/persistence view of the richer
/// parse-time `Offer` model — flat, primitive, JSON-round-trippable.
class OfferSummary {
  final GigPlatform platform;
  final Verdict verdict;
  final double payout; // dollars
  final double pickupKm; // dead mileage to the rider; 0 when unknown
  final double totalKm; // pickup + dropoff
  final double totalMinutes; // pickup + trip; 0 when unknown
  final DateTime seenAt;

  const OfferSummary({
    required this.platform,
    required this.verdict,
    required this.payout,
    required this.totalKm,
    required this.seenAt,
    this.pickupKm = 0,
    this.totalMinutes = 0,
  });

  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;

  /// Dollars per hour; 0 when no time was parsed (UI hides it, no ∞).
  double get pricePerHour => totalMinutes > 0 ? payout / totalMinutes * 60 : 0;

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'verdict': verdict.name,
    'payout': payout,
    'pickupKm': pickupKm,
    'totalKm': totalKm,
    'totalMinutes': totalMinutes,
    'seenAt': seenAt.millisecondsSinceEpoch,
  };

  factory OfferSummary.fromJson(Map<String, dynamic> j) => OfferSummary(
    platform: GigPlatform.values
        .where((p) => p.name == j['platform'])
        .firstOrNull ??
        GigPlatform.uber,
    verdict: Verdict.values.where((v) => v.name == j['verdict']).firstOrNull ??
        Verdict.unknown,
    payout: (j['payout'] as num?)?.toDouble() ?? 0,
    pickupKm: (j['pickupKm'] as num?)?.toDouble() ?? 0,
    totalKm: (j['totalKm'] as num?)?.toDouble() ?? 0,
    totalMinutes: (j['totalMinutes'] as num?)?.toDouble() ?? 0,
    seenAt: DateTime.fromMillisecondsSinceEpoch(
      (j['seenAt'] as num?)?.toInt() ?? 0,
    ),
  );
}
