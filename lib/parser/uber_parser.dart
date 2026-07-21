import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Reads an Uber Driver offer card (docs/REFERENCE_ANALYSIS "Uber offer card").
///
/// Anchors, on the joined node text:
///   • payout — first `$N` (the huge top-left number). Uber pay is **gross**.
///   • pickup — `N mins (X km) away`   → pickupMinutes = N, pickupKm = X
///   • trip   — `N mins (X km) trip`   → dropoffMinutes = N, dropoffKm = X
///
/// Uber splits pickup and trip into two labeled rows, so the `away`/`trip`
/// suffixes disambiguate them regardless of order. The strict offer-detection
/// contract (see [ParserPatterns]) also requires an Accept affordance and no
/// browse markers, so the home/online map (which has neither an `away` nor a
/// `trip` row) can't be mistaken for an offer. If the trip row is missing we
/// bail to `null` (fail safe) — the acceptance-rate gate hides the upfront
/// numbers entirely (AUDIT #3, ROADMAP M3).
class UberParser implements OfferParser {
  const UberParser();

  @override
  GigPlatform get platform => GigPlatform.uber;

  @override
  String get tunedAgainst =>
      'Uber Driver 2026.26 (references/Uber.jpg, new (1))';

  // "4 mins (0.8 km) away" / "37 mins (37.0 km) trip". Minutes and km both
  // captured; tolerant of "min"/"mins" and spacing.
  static final _pickup = RegExp(
    r'(\d+)\s*mins?\s*\(\s*([\d.]+)\s*km\s*\)\s*away',
    caseSensitive: false,
  );
  static final _trip = RegExp(
    r'(\d+)\s*mins?\s*\(\s*([\d.]+)\s*km\s*\)\s*trip',
    caseSensitive: false,
  );

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');

    // Contract gate: a real offer is takeable (Accept) and isn't a browse map.
    if (!ParserPatterns.hasAcceptAction(nodeTexts)) return null;
    if (ParserPatterns.looksLikeBrowse(joined)) return null;

    final payout = ParserPatterns.findPayout(nodeTexts);
    final pickup = _pickup.firstMatch(joined);
    final trip = _trip.firstMatch(joined);

    // Need the money and at least the trip distance to score anything.
    if (payout == null || trip == null) return null;

    final dropoffMin = double.tryParse(trip.group(1)!) ?? 0;
    final dropoffKm = double.tryParse(trip.group(2)!) ?? 0;
    if (dropoffKm <= 0) return null;

    // Pickup leg is optional — some cards show only the trip. Default to 0 so
    // totalKm/totalMinutes still make sense.
    final pickupMin = pickup != null
        ? (double.tryParse(pickup.group(1)!) ?? 0)
        : 0.0;
    final pickupKm = pickup != null
        ? (double.tryParse(pickup.group(2)!) ?? 0)
        : 0.0;

    return Offer(
      platform: GigPlatform.uber,
      payout: payout,
      pickupKm: pickupKm,
      dropoffKm: dropoffKm,
      pickupMinutes: pickupMin,
      dropoffMinutes: dropoffMin,
      payIsNet: false, // Uber shows gross pay
      rawText: joined,
    );
  }
}
