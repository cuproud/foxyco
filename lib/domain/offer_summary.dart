import 'platform.dart';
import 'verdict.dart';

/// A scored offer as shown on the dashboard's "Last offer" card and logged for
/// the daily tally. This is the display/persistence view; the richer parse-time
/// `Offer` model (payout, pickupKm, dropoffKm, payIsNet) lands with the parser
/// in M3 (see docs/ARCHITECTURE.md).
class OfferSummary {
  final GigPlatform platform;
  final Verdict verdict;
  final double payout; // dollars
  final double totalKm; // pickup + dropoff
  final DateTime seenAt;

  const OfferSummary({
    required this.platform,
    required this.verdict,
    required this.payout,
    required this.totalKm,
    required this.seenAt,
  });

  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;
}
