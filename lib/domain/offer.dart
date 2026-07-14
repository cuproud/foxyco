import 'platform.dart';

/// A raw offer as read off a gig app's screen by a parser (M3), before it's
/// scored. Pure Dart — no Flutter, no plugins (ARCHITECTURE "one hard rule").
///
/// This is the parse-time model; the leaner [OfferSummary] is the display/log
/// view the dashboard shows. Distances and times are kept SPLIT (pickup vs
/// dropoff) exactly as Uber/Hopp present them — FoxyCo's added value is summing
/// them (REFERENCE_ANALYSIS: "neither app shows the sum or the $/km").
///
/// `payIsNet` distinguishes Hopp (net, tax included) from Uber (gross) so the
/// profit engine can treat them correctly later; the MVP verdict just uses
/// [pricePerKm]. `rawText` is the joined node text, kept for debugging a parse
/// (AUDIT #3 — dump the nodes to re-tune a broken selector).
class Offer {
  final GigPlatform platform;
  final double payout; // dollars
  final double pickupKm;
  final double dropoffKm;
  final double pickupMinutes;
  final double dropoffMinutes;
  final bool payIsNet; // Hopp = true (net), Uber = false (gross)
  final String? rawText;

  const Offer({
    required this.platform,
    required this.payout,
    required this.pickupKm,
    required this.dropoffKm,
    this.pickupMinutes = 0,
    this.dropoffMinutes = 0,
    this.payIsNet = false,
    this.rawText,
  });

  double get totalKm => pickupKm + dropoffKm;
  double get totalMinutes => pickupMinutes + dropoffMinutes;

  /// Dollars per km over the whole job (pickup + trip). The verdict input.
  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;

  /// Dollars per hour over the whole job — the Maxymo-style headline metric.
  /// Zero when no time was parsed, so the pill can hide it rather than show ∞.
  double get pricePerHour => totalMinutes > 0 ? payout / totalMinutes * 60 : 0;

  @override
  String toString() =>
      'Offer(${platform.label}, \$$payout, ${totalKm}km, ${totalMinutes}min, '
      'net=$payIsNet)';
}
