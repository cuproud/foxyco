import 'platform.dart';

/// A raw offer as read off a gig app's screen by a parser (M3), before it's
/// scored. Pure Dart — no Flutter, no plugins (ARCHITECTURE "one hard rule").
///
/// This is the parse-time model; the leaner [OfferSummary] is the display/log
/// view the dashboard shows. Distances and times are kept SPLIT (pickup vs
/// dropoff) exactly as Uber/Hopp present them — FoxyCo's added value is summing
/// them because source apps may show separate legs rather than the sum.
///
/// `payIsNet` distinguishes Hopp (net, tax included) from Uber (gross) so the
/// profit engine can treat them correctly later; the MVP verdict just uses
/// [pricePerKm]. `rawText` is the joined node text, kept for debugging a parse
/// (AUDIT #3 — dump the nodes to re-tune a broken selector).
class Offer {
  final GigPlatform platform;
  final double payout; // dollars
  /// Promotional amount already included in [payout] (Lyft bonus/bonuses).
  /// Kept separate for History; never add it again when scoring.
  final double bonus;
  final double pickupKm;
  final double dropoffKm;
  final double pickupMinutes;
  final double dropoffMinutes;
  final bool payIsNet; // Hopp = true (net), Uber = false (gross)

  /// Product tier / ride type as read off the card ("UberX", "Comfort",
  /// "Share", "Radar match", …), or null when the parser can't tell. Display
  /// only — never feeds the verdict. See [UberParser].
  final String? category;

  /// True when the card was offered while another Lyft trip was active via
  /// "Add to queue". It is still a normal offer, but useful context later.
  final bool isQueued;

  /// Number of Uber Eats deliveries bundled into this card; 0 for rides.
  final int deliveryCount;

  /// Optional delivery workload. Ride parsers leave these at zero.
  final int itemCount;
  final int unitCount;

  final String? rawText;

  const Offer({
    required this.platform,
    required this.payout,
    this.bonus = 0,
    required this.pickupKm,
    required this.dropoffKm,
    this.pickupMinutes = 0,
    this.dropoffMinutes = 0,
    this.payIsNet = false,
    this.category,
    this.isQueued = false,
    this.deliveryCount = 0,
    this.itemCount = 0,
    this.unitCount = 0,
    this.rawText,
  });

  double get totalKm => pickupKm + dropoffKm;
  double get totalMinutes => pickupMinutes + dropoffMinutes;

  /// Uber rides and Eats share one package/parser, but use different rules.
  GigPlatform get rulesPlatform =>
      platform == GigPlatform.uber && deliveryCount > 0
      ? GigPlatform.uberEats
      : platform;

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
