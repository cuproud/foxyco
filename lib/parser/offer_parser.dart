import '../domain/offer.dart';
import '../domain/platform.dart';

/// One platform's rule for turning a screen's text into an [Offer]. Pure Dart —
/// fed the accessibility node texts, tuned against the layouts in
/// docs/REFERENCE_ANALYSIS.md, and unit-tested with captured fixtures.
///
/// **Fail safe is the contract:** return `null` whenever confidence is low
/// (a field is missing, the layout changed, the offer half-rendered). A `null`
/// shows nothing; a wrong `Offer` shows a confident wrong verdict, which is
/// worse than silence (AUDIT #3). Every parser is tagged with the app version
/// it was tuned against so a break is easy to date and re-tune.
abstract interface class OfferParser {
  /// Which app this parser reads. The registry dispatches by foreground package.
  GigPlatform get platform;

  /// Version string of the target app this parser was last tuned against —
  /// stamped into fixtures so a selector break is traceable to an app update.
  String get tunedAgainst;

  /// Parse the flattened list of on-screen node texts into an [Offer], or `null`
  /// if the screen isn't a recognizable, complete offer.
  Offer? parse(List<String> nodeTexts);
}

/// Shared building blocks for the strict per-platform **offer-detection
/// contract**. Every parser must satisfy the same positive signature before it
/// emits an [Offer] — this is what stops the pill painting garbage over browse
/// maps, home screens, and scheduled-ride lists (bugs 1–5, HANDOFF 2026-07-12):
///
///   1. an **action affordance** — a real, takeable offer shows Accept / Match;
///      no map/browse/home screen does ([hasAcceptAction]).
///   2. a **clean payout** — the first `$` that isn't a toll / fee / tip /
///      bonus / surge / rate line ([findPayout]).
///   3. the right **leg shape** — a real card is exactly a pickup + a dropoff.
///      Fewer means half-rendered; more means we latched onto a *list* of rides.
///   4. no **browse markers** — belt-and-braces negative gate ([looksLikeBrowse]).
///
/// The gate is deliberately strict: over-rejecting a real offer (silence) is
/// safe; a confident wrong verdict is not (AUDIT #3). A screen that fails ANY
/// clause parses to `null`.
class ParserPatterns {
  ParserPatterns._();

  /// A dollar amount anywhere in a string.
  static final payout = RegExp(r'\$\s?(\d+(?:\.\d{1,2})?)');

  /// Lines whose dollar figure is NOT the payout: tolls, fees, tips, bonuses,
  /// and rate estimates ("$28.45/hr"). Real device data (Hopp on a 407 trip)
  /// shows a `Toll Fee • $2.10` node ABOVE the payout, so a naive first-$ match
  /// grabs the toll. Skip any node mentioning these before taking its amount.
  static final _notPayout = RegExp(
    r'\b(toll|fee|tip|bonus|surge|/\s*hr|per\s*hr|est\.?\s*rate)\b|/hr',
    caseSensitive: false,
  );

  /// A timeline leg: "N min · X km" / "N mins • X km". Shared by Hopp and Lyft,
  /// which use the same dot-line pickup→dropoff card. Tolerant of min/mins and
  /// the separator (middot / bullet / hyphen) between time and distance.
  ///
  /// Note the REQUIRED "km": a map bubble like "$12 Lyft · 1 min away" has a
  /// time but no distance, so it never counts as a leg — that browse-map noise
  /// (bug1 (8)) can't be stitched into a fake trip.
  static final leg = RegExp(
    r'(\d+)\s*mins?\s*[·•⋅\-]\s*([\d.]+)\s*km',
    caseSensitive: false,
  );

  /// The takeable-offer affordance. A live offer card always offers a way to
  /// take it — "Accept" (Uber/Lyft) or "Match" (Hopp). Browse maps, home
  /// screens, and "Ride Finder"/"Go Online" screens never show one, so its
  /// ABSENCE is the single strongest "this isn't an offer" signal.
  static final _acceptAction = RegExp(r'\b(accept|match)\b', caseSensitive: false);
  static bool hasAcceptAction(List<String> nodeTexts) =>
      nodeTexts.any(_acceptAction.hasMatch);

  /// Negative markers that only appear on browse / home / map / scheduled-list
  /// screens — never on a single incoming offer card. Captured from the real
  /// device screenshots (bug1 (6) Ride Finder browse, bug1 (8) map bubbles,
  /// Lyft scheduled-ride home). A hit means "not an offer" outright.
  static final _browseMarker = RegExp(
    r'scheduled ride|rides? available|ride finder|looking for rides|'
    r'open requests|go online|priority mode|earnings goal|turbo|'
    r'wait in your area|min away|select a ride',
    caseSensitive: false,
  );
  static bool looksLikeBrowse(String joined) => _browseMarker.hasMatch(joined);

  /// Any button that appears on a live offer card — Accept/Match (take) or
  /// Decline/Dismiss (reject). Broader than [_acceptAction] (which gates a
  /// strict parse) because for the overlay's *lifecycle* a lone "Decline" frame
  /// still means the card is up.
  static final _cardAction =
      RegExp(r'\b(accept|match|decline|dismiss)\b', caseSensitive: false);

  /// Cheap "are we STILL looking at an offer card?" probe for the overlay's
  /// pill lifecycle — deliberately loose, NOT the strict parse. Gig apps
  /// machine-gun half-rendered frames while a card is up: one frame is just the
  /// payout, the next just the "Accept" button, the next just a leg row. Any of
  /// those hallmarks means the card hasn't left, so the pill must stay. Only a
  /// positively-non-card screen ([looksLikeBrowse]) should drop it. This is what
  /// stops the pill vanishing mid-read when a single field flickers out of the
  /// accessibility tree (device logs 2026-07-13/14).
  static bool looksLikeOfferCard(List<String> nodeTexts) {
    if (findPayout(nodeTexts) != null) return true;
    if (nodeTexts.any(_cardAction.hasMatch)) return true;
    return leg.hasMatch(nodeTexts.join(' '));
  }

  /// The payout, scanning nodes in view order and skipping toll/fee/tip/bonus/
  /// rate lines. Returns the first genuine dollar amount, or null if none.
  ///
  /// Per-node (not joined) so a fee line's `$` can be excluded without dropping
  /// the whole screen. Unlike the previous version this does NOT fall back to a
  /// filtered-out amount: if every candidate was a fee/rate line we'd rather
  /// return null (and show nothing) than take a number we already flagged wrong.
  static double? findPayout(List<String> nodeTexts) {
    for (final node in nodeTexts) {
      if (!payout.hasMatch(node)) continue;
      if (_notPayout.hasMatch(node)) continue;
      return double.tryParse(payout.firstMatch(node)!.group(1)!);
    }
    return null;
  }

  /// Upper bound on timeline legs for a single offer. A normal ride is 2 legs
  /// (pickup + dropoff); a **multi-stop** ride adds one row per stop, so a
  /// 3-stop trip is 5 rows. Beyond this we assume we latched onto a *list* of
  /// rides (a scheduled-ride list) rather than one card and bail.
  // ponytail: 6 = pickup + up to 5 trip legs. Raise if real offers exceed it.
  static const _maxLegs = 6;

  /// Fold a dot-line timeline's legs into pickup + whole-trip totals, so a ride
  /// with intermediate STOPS scores on its true total distance/time instead of
  /// being rejected for not being "exactly two legs". The first leg is the
  /// deadhead to the rider (pickup); every remaining leg — the final dropoff and
  /// any mid-trip stops — is summed into the trip total. Returns `null` (fail
  /// safe) when there are too few legs (half-rendered) or too many ([_maxLegs],
  /// probably a list), or when the distances don't add up to anything.
  ///
  /// Shared by Hopp and Lyft, which use the same pickup-first timeline; feed it
  /// `leg.allMatches(joined).toList()`.
  static ({double pickupKm, double pickupMin, double tripKm, double tripMin})?
      foldLegs(List<RegExpMatch> legs) {
    if (legs.length < 2 || legs.length > _maxLegs) return null;
    final pickupMin = double.tryParse(legs.first.group(1)!) ?? 0;
    final pickupKm = double.tryParse(legs.first.group(2)!) ?? 0;
    var tripMin = 0.0;
    var tripKm = 0.0;
    for (final leg in legs.skip(1)) {
      tripMin += double.tryParse(leg.group(1)!) ?? 0;
      tripKm += double.tryParse(leg.group(2)!) ?? 0;
    }
    if (pickupKm + tripKm <= 0) return null;
    return (pickupKm: pickupKm, pickupMin: pickupMin, tripKm: tripKm, tripMin: tripMin);
  }
}
