import '../domain/offer.dart';
import '../domain/distance_unit.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Reads an Uber Driver offer card.
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
/// numbers entirely.
class UberParser implements OfferParser {
  const UberParser();

  @override
  GigPlatform get platform => GigPlatform.uber;

  @override
  String get tunedAgainst =>
      'Uber Driver 2026.26 (references/Uber.jpg, new (1))';

  // "4 mins (0.8 km) away" / "37 mins (37.0 km) trip" / "1 hr 2 min (54.6 km)
  // trip". An OPTIONAL leading "N hr" is captured (group 1) so long trips don't
  // lose the hour — without it "1 hr 2 min" parsed as 2 min and $/hr came out
  // ~30× high (device 2026-07-23: $34.22 / 54.6 km showed $342/hr). Groups:
  // 1=hours?, 2=minutes, 3=distance, 4=unit. Tolerant of US mile cards.
  static const _leg =
      r'(?:(\d+)\s*h(?:rs?|ours?)?\s*)?(\d+)\s*mins?'
      r'\s*\(\s*([\d.]+)\s*(km|mi|miles?)\s*\)\s*';
  static final _pickup = RegExp(
    '$_leg'
    'away',
    caseSensitive: false,
  );
  static final _trip = RegExp(
    '$_leg'
    'trip',
    caseSensitive: false,
  );
  static final _total = RegExp(
    '$_leg'
    'total',
    caseSensitive: false,
  );
  static final _delivery = RegExp(
    r'\bdelivery(?:\s*\((\d+)\))?(?!\w)',
    caseSensitive: false,
  );

  static double _minutes(RegExpMatch m) {
    final hr = m.group(1) != null ? (double.tryParse(m.group(1)!) ?? 0) : 0;
    final min = double.tryParse(m.group(2)!) ?? 0;
    return hr * 60 + min;
  }

  static double _kilometres(RegExpMatch m) {
    final value = double.tryParse(m.group(3)!) ?? 0;
    final unit = m.group(4)?.toLowerCase();
    return unit == 'mi' || unit?.startsWith('mile') == true
        ? value * DistanceUnit.kilometresPerMile
        : value;
  }

  // Product tier / ride type, longest-first so "UberXL"/"Uber Share" win over a
  // bare "Uber X". Matched against the joined card text (references/*Uber*).
  static final _tiers = <String, RegExp>{
    'Comfort Electric': RegExp(r'comfort\s*electric', caseSensitive: false),
    'XL': RegExp(r'\buber\s*xl\b', caseSensitive: false),
    'Share': RegExp(r'\b(uber\s*)?(share|pool)\b', caseSensitive: false),
    'Green': RegExp(r'\buber\s*green\b', caseSensitive: false),
    'Pet': RegExp(r'\buber\s*pet\b', caseSensitive: false),
    'Premier': RegExp(r'\b(uber\s*)?premier\b', caseSensitive: false),
    'Black': RegExp(r'\buber\s*black\b', caseSensitive: false),
    'Connect': RegExp(r'\buber\s*connect\b', caseSensitive: false),
    'Comfort': RegExp(r'\b(uber\s*)?comfort\b', caseSensitive: false),
    'UberX': RegExp(r'\buber\s*x\b', caseSensitive: false),
  };

  /// Compose the display category: product tier plus a "Radar" note when the
  /// card is a matched/radar ride (Uber shows a **Match** button for those, an
  /// **Accept** button for a plain dispatch). Null when neither is present.
  static String? _category(List<String> nodeTexts, String joined) {
    String? tier;
    for (final e in _tiers.entries) {
      if (e.value.hasMatch(joined)) {
        tier = e.key;
        break;
      }
    }
    // Radar/matched ride: a "Match" affordance without a plain "Accept".
    final radar =
        RegExp(r'\bmatch\b', caseSensitive: false).hasMatch(joined) &&
        !RegExp(r'\baccept\b', caseSensitive: false).hasMatch(joined);
    if (tier == null) return radar ? 'Radar match' : null;
    return radar ? '$tier · Radar' : tier;
  }

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');

    // OCR can miss the dark Accept/Match button. Uber tier + payout + its
    // labelled away/trip rows are still a complete, platform-specific card.
    final hasUberTier = _tiers.values.any((tier) => tier.hasMatch(joined));
    if (!ParserPatterns.hasAcceptAction(nodeTexts) && !hasUberTier) return null;
    if (ParserPatterns.looksLikeBrowse(joined)) return null;

    final payout = ParserPatterns.findPayout(nodeTexts);
    final delivery = _delivery.firstMatch(joined);
    final total = _total.firstMatch(joined);
    if (payout != null && delivery != null && total != null) {
      final distance = _kilometres(total);
      if (distance <= 0) return null;
      final count = int.tryParse(delivery.group(1) ?? '') ?? 1;
      return Offer(
        platform: GigPlatform.uber,
        payout: payout,
        pickupKm: 0,
        dropoffKm: distance,
        dropoffMinutes: _minutes(total),
        category: 'Eats · $count ${count == 1 ? 'delivery' : 'deliveries'}',
        deliveryCount: count,
        rawText: joined,
      );
    }
    final pickup = _pickup.firstMatch(joined);
    final trip = _trip.firstMatch(joined);

    // Need the money and at least the trip distance to score anything.
    if (payout == null || trip == null) return null;

    final dropoffMin = _minutes(trip);
    final dropoffKm = _kilometres(trip);
    if (dropoffKm <= 0) return null;

    // Pickup leg is optional — some cards show only the trip. Default to 0 so
    // totalKm/totalMinutes still make sense.
    final pickupMin = pickup != null ? _minutes(pickup) : 0.0;
    final pickupKm = pickup != null ? _kilometres(pickup) : 0.0;

    return Offer(
      platform: GigPlatform.uber,
      payout: payout,
      pickupKm: pickupKm,
      dropoffKm: dropoffKm,
      pickupMinutes: pickupMin,
      dropoffMinutes: dropoffMin,
      payIsNet: false, // Uber shows gross pay
      category: _category(nodeTexts, joined),
      rawText: joined,
    );
  }
}
