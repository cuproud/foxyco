import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Reads a Lyft Driver offer card (references/bug1 (1).jpg, new (3)-(5).jpg).
///
/// Lyft is the worst offender for false positives (HANDOFF bugs 2, 3, 4): its
/// online/home screen is a MAP covered in "$N Lyft · M min away" pickup bubbles
/// and a "$37.64 | 3" Turbo/streak banner at the very top, plus a "Ride Finder"
/// list of SUGGESTED SCHEDULED RIDE cards. The old parser grabbed the banner
/// number and stitched two scheduled legs into a fake trip.
///
/// The strict offer-detection contract kills all of that:
///   • **Accept required** — a real card (bug1 (1)) has an `Accept` button; the
///     browse map has `Go Online` / `Ride Finder` and no Accept.
///   • **browse markers rejected** — `Ride Finder`, `wait in your area`,
///     `min away` (the map bubbles), `scheduled ride`, `Go Online`, etc.
///   • **exactly two km legs** — the map bubbles carry NO "km", so they aren't
///     legs; a scheduled-ride list has more than two.
///
/// Card anchors (all clauses must hold, else `null` — fail safe):
///   • payout — first clean `$N`; the `Incl. CA$X bonus` and `$Y/hr est. rate`
///     lines are skipped by [ParserPatterns.findPayout].
///   • two `N min · X km` legs — pickup first, dropoff last (timeline order).
class LyftParser implements OfferParser {
  const LyftParser();

  @override
  GigPlatform get platform => GigPlatform.lyft;

  @override
  String get tunedAgainst => 'Lyft Driver 2026.26 (references/new (3)-(5).jpg)';

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');

    // Contract gate 1: takeable + not a browse/map/scheduled screen.
    if (!ParserPatterns.hasAcceptAction(nodeTexts)) return null;
    if (ParserPatterns.looksLikeBrowse(joined)) return null;

    final payout = ParserPatterns.findPayout(nodeTexts);
    final legs = ParserPatterns.leg.allMatches(joined).toList();

    // Contract gate 2: money + a pickup and at least one trip leg. A plain ride
    // is two legs; a MULTI-STOP ride adds a row per stop, all summed into the
    // trip total by [foldLegs]. Too few (half-rendered) or too many (a ride
    // list) → null. First row = pickup, the rest = trip.
    final t = ParserPatterns.foldLegs(legs);
    if (payout == null || t == null) return null;

    return Offer(
      platform: GigPlatform.lyft,
      payout: payout,
      pickupKm: t.pickupKm,
      dropoffKm: t.tripKm,
      pickupMinutes: t.pickupMin,
      dropoffMinutes: t.tripMin,
      payIsNet: false, // Lyft shows gross pay (bonus shown separately)
      rawText: joined,
    );
  }
}
