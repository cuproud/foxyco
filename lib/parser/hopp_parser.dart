import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Reads a Hopp Driver offer card (docs/REFERENCE_ANALYSIS "Hopp offer card").
///
/// The card (references/bug1 (5).jpg) always carries: a `Hopp` chip, an
/// Accept/Match affordance, one clean `$N` payout, and EXACTLY two `N min · X km`
/// timeline rows (pickup then dropoff). The strict offer-detection contract
/// (see [ParserPatterns]) requires all of these — a browse/home screen has no
/// Accept and no leg pairs, so it can never masquerade as an offer.
///
/// Anchors, on the joined node text:
///   • payout — first `$N` that isn't a toll/fee line. Hopp pay is **net**.
///   • the `NET` / `tax included` flag → `payIsNet = true`.
///   • two `N min · X km` rows. Unlike Uber, Hopp does NOT label them
///     `away`/`trip`; they're told apart by the dot-line timeline ORDER — the
///     pickup row renders first, the dropoff row second. Node order follows the
///     view hierarchy, so first match = pickup, last = dropoff.
///
/// Anything that fails a clause → `null` (fail safe, AUDIT #3).
class HoppParser implements OfferParser {
  const HoppParser();

  @override
  GigPlatform get platform => GigPlatform.hopp;

  @override
  String get tunedAgainst =>
      'Hopp Driver 2026.07 (references/Hopp.jpg, new (2))';

  // Net-pay marker. Hopp prints "(NET, tax included)" beside the payout.
  static final _net = RegExp(r'\bnet\b|tax\s*included', caseSensitive: false);

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');

    // Contract gate 1: a real offer is takeable and isn't a browse screen.
    if (!ParserPatterns.hasAcceptAction(nodeTexts)) return null;
    if (ParserPatterns.looksLikeBrowse(joined)) return null;

    final payout = ParserPatterns.findPayout(nodeTexts);
    final legs = ParserPatterns.leg.allMatches(joined).toList();

    // Contract gate 2: the money plus a pickup + at least one trip leg. A plain
    // ride is two legs; a MULTI-STOP ride adds a row per stop, all summed into
    // the trip total by [foldLegs]. Too few (half-rendered) or too many (a list
    // of rides) → null. First row = pickup, the rest = trip.
    final t = ParserPatterns.foldLegs(legs);
    if (payout == null || t == null) return null;

    return Offer(
      platform: GigPlatform.hopp,
      payout: payout,
      pickupKm: t.pickupKm,
      dropoffKm: t.tripKm,
      pickupMinutes: t.pickupMin,
      dropoffMinutes: t.tripMin,
      payIsNet: _net.hasMatch(joined),
      rawText: joined,
    );
  }
}
