import '../domain/offer.dart';
import '../domain/distance_unit.dart';
import '../domain/platform.dart';

/// One platform's rule for turning a screen's text into an [Offer]. Pure Dart —
/// fed the accessibility node texts, tuned against observed offer layouts,
/// and unit-tested with captured fixtures.
///
/// **Fail safe is the contract:** return `null` whenever confidence is low
/// (a field is missing, the layout changed, the offer half-rendered). A `null`
/// shows nothing; a wrong `Offer` shows a confident wrong verdict, which is
/// worse than silence. Every parser is tagged with the app version
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

  /// Dollar amounts that are clearly attached to a non-payout label. This is
  /// deliberately applied to the text immediately around EACH amount rather
  /// than to the whole accessibility node: Lyft sometimes exposes
  /// `Total $15.00 + $3.00 bonus included` as one node. Rejecting that whole
  /// node loses the real total and caused intermittent Lyft misses.
  static final _excludedAmountBefore = RegExp(
    r'(?:toll|fee|tip|bonus|surge|extra|quest|promotions?|per\s*hr|est\.?\s*rate)'
    r'[^\$]{0,8}$',
    caseSensitive: false,
  );
  static final _excludedAmountAfter = RegExp(
    r'^\s*(?:km\b|mi\b|miles?\b|/\s*hr|per\s*hr|toll|fee|tip|'
    r'(?:in(?:cluded)?\s+)?bonus(?:es)?|surge|extra|quest|'
    r'promotions?)\b',
    caseSensitive: false,
  );

  /// A timeline leg: "N min · X km" / "N mins • X km". Shared by Hopp and Lyft,
  /// which use the same dot-line pickup→dropoff card. Tolerant of min/mins and
  /// the separator (middot / bullet / hyphen) between time and distance. The
  /// separator is optional because on-device OCR routinely omits that tiny
  /// decorative glyph while preserving both labelled values.
  ///
  /// Note the REQUIRED distance unit: a map bubble like "$12 Lyft · 1 min away" has a
  /// time but no distance, so it never counts as a leg — that browse-map noise
  /// (bug1 (8)) can't be stitched into a fake trip.
  static final leg = RegExp(
    r'(\d+)\s*mins?\s*(?:[·•⋅\-]\s*)?([\d.]+)\s*(km|mi|miles?)\b',
    caseSensitive: false,
  );

  /// The takeable-offer affordance. A live offer card always offers a way to
  /// take it — "Accept" (Uber/Lyft) or "Match" (Hopp). Browse maps, home
  /// screens, and "Ride Finder"/"Go Online" screens never show one, so its
  /// ABSENCE is the single strongest "this isn't an offer" signal.
  static final _acceptAction = RegExp(
    r'\b(accept|match|add\s+to\s+queue)\b',
    caseSensitive: false,
  );
  static bool hasAcceptAction(List<String> nodeTexts) =>
      nodeTexts.any(_acceptAction.hasMatch);

  static final _reserveAction = RegExp(
    r'^\s*reserve\s*$',
    caseSensitive: false,
  );
  static bool hasReserveAction(List<String> nodeTexts) =>
      nodeTexts.any(_reserveAction.hasMatch);
  static bool hasOfferAction(List<String> nodeTexts) =>
      hasAcceptAction(nodeTexts) || hasReserveAction(nodeTexts);

  static final _scheduledTime = RegExp(
    r'\b(?:today|tomorrow)\b[^\d]{0,4}\d{1,2}:\d{2}\s*(?:a\.?m\.?|p\.?m\.?)',
    caseSensitive: false,
  );
  static bool hasScheduledTime(List<String> nodeTexts) =>
      nodeTexts.any(_scheduledTime.hasMatch);

  /// Negative markers that only appear on browse / home / map / scheduled-list
  /// screens — never on a single incoming offer card. Captured from the real
  /// device screenshots (bug1 (6) Ride Finder browse, bug1 (8) map bubbles,
  /// Lyft scheduled-ride home). A hit means "not an offer" outright.
  static final _browseMarker = RegExp(
    r'scheduled ride|rides? available|ride finder|looking for rides|'
    r'open requests|go online|priority mode|earnings goal|turbo|'
    r'wait in your area|min away|select a ride|'
    // Uber home-map hallmarks: never present on an offer card, always on the
    // between-offers map — lets the pill clear promptly instead of riding the
    // minVisible floor (device 2026-07-19: pill lingered until next offer).
    r'finding trips|trip planner|go offline',
    caseSensitive: false,
  );
  static bool looksLikeBrowse(String joined) => _browseMarker.hasMatch(joined);

  /// A scheduled-ride list is the one Lyft browse surface that can resemble a
  /// complete live card: several listed rides can contribute a payout and two
  /// or more `min · km` rows, while an `Accept` node from another window may
  /// leak into the merged accessibility read. Keep this stronger marker
  /// separate so Lyft can always reject the list without rejecting ordinary
  /// map chrome that sits behind a genuine offer window.
  static final _scheduledRideMarker = RegExp(
    r'scheduled ride',
    caseSensitive: false,
  );
  static bool looksLikeScheduledRideList(String joined) =>
      _scheduledRideMarker.hasMatch(joined);

  /// Any button that appears on a live offer card — Accept/Match (take) or
  /// Decline/Dismiss (reject). Broader than [_acceptAction] (which gates a
  /// strict parse) because for the overlay's *lifecycle* a lone "Decline" frame
  /// still means the card is up.
  static final _cardAction = RegExp(
    r'\b(accept|match|add\s+to\s+queue|reserve|decline|dismiss)\b',
    caseSensitive: false,
  );

  /// Cheap "are we STILL looking at an offer card?" probe for the overlay's
  /// pill lifecycle — deliberately loose, NOT the strict parse. Gig apps
  /// machine-gun half-rendered frames while a card is up: one frame is just the
  /// payout, the next just the "Accept" button, the next just a leg row. Any of
  /// those hallmarks means the card hasn't left, so the pill must stay. Only a
  /// positively-non-card screen ([looksLikeBrowse]) should drop it. This is what
  /// stops the pill vanishing mid-read when a single field flickers out of the
  /// accessibility tree (device logs 2026-07-13/14).
  static bool looksLikeOfferCard(
    List<String> nodeTexts, {
    bool onBrowse = false,
  }) {
    // Uber's browse map exposes a positive earnings chip (for example
    // "$17.30") but no offer card. Require a card-specific action or leg when
    // browse chrome is present, otherwise that chip can hold an old verdict
    // forever.
    if (onBrowse &&
        !nodeTexts.any(_cardAction.hasMatch) &&
        !leg.hasMatch(nodeTexts.join(' '))) {
      return false;
    }
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
  static double? findPayout(Iterable<String> nodeTexts) {
    for (final node in nodeTexts) {
      for (final match in payout.allMatches(node)) {
        final before = node.substring(0, match.start);
        final after = node.substring(match.end);
        if (_excludedAmountBefore.hasMatch(before) ||
            _excludedAmountAfter.hasMatch(after)) {
          continue;
        }
        final amount = double.tryParse(match.group(1)!);
        // $0.00 is never an offer — it's Uber's home-map earnings chip ("Home |
        // $0.00"), which rides in every merged read. Treating it as a payout kept
        // looksLikeOfferCard true on map frames, so the pill never cleared
        // (device 2026-07-19).
        if (amount == null || amount <= 0) continue;
        return amount;
      }
    }
    return null;
  }

  /// Promotional amount included in the displayed total. Lyft currently uses
  /// "Incl. CA$1.73 bonus" / "CA$4.30 in bonuses". Return zero when no
  /// explicit bonus label exists; a plain dollar value is never guessed.
  static double findBonus(List<String> nodeTexts) {
    final bonusLabel = RegExp(r'\bbonus(?:es)?\b', caseSensitive: false);
    for (final node in nodeTexts) {
      if (!bonusLabel.hasMatch(node)) continue;
      // If total and bonus share one node ("Total $15 + $3 bonus"), the
      // bonus-labeled amount is the final one. Single-amount Lyft lines work
      // identically.
      final matches = payout.allMatches(node).toList();
      final match = matches.lastOrNull;
      final amount = match == null ? null : double.tryParse(match.group(1)!);
      if (amount != null && amount > 0) return amount;
    }
    return 0;
  }

  /// Strong positive evidence that an offer from [platform] was accepted.
  /// These phrases come from the supplied live-trip screenshots and avoid
  /// rider names/addresses. Ambiguous blank/navigation frames stay unknown.
  static bool looksLikeQueuedOfferAccepted(
    GigPlatform platform,
    List<String> nodeTexts,
  ) =>
      platform == GigPlatform.lyft &&
      nodeTexts.any((node) => node.trim().toLowerCase() == 'added to queue');

  static bool looksLikeAcceptedTrip(
    GigPlatform platform,
    List<String> nodeTexts,
  ) {
    final normalized = nodeTexts
        .map(
          (node) => node.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
        )
        .where((node) => node.isNotEmpty)
        .toList();
    if (platform == GigPlatform.lyft) {
      // "arrive" is only strong when it is the button node itself. Matching it
      // in the whole screen can misread instructional or address text.
      return normalized.any(
        (node) =>
            node == 'added to queue' ||
            node == 'arrive' ||
            RegExp(r'\bpassenger notified\b').hasMatch(node) ||
            RegExp(r'\bslide to (?:pick up|drop off)\b').hasMatch(node),
      );
    }
    if (platform == GigPlatform.hopp) {
      // Real Hopp flow, captured 2026-08-04:
      // Arrived → Waiting/Start Trip → End Trip → Confirm Price → Rate passenger.
      // Keep the generic word "waiting" timer-shaped so unrelated copy cannot
      // turn a declined offer into an accepted one.
      return normalized.any(
        (node) =>
            node == 'arrived' ||
            node == 'you have arrived' ||
            node == 'wait here' ||
            RegExp(r'^\d{1,2}:\d{2} waiting$').hasMatch(node) ||
            node == 'start trip' ||
            node == 'end trip' ||
            node == 'confirm price' ||
            node == 'rate passenger' ||
            node == 'navigate to rider' ||
            node == 'arrive at pickup' ||
            node == 'complete trip',
      );
    }
    if (platform != GigPlatform.uber) return false;
    final joined = normalized.join(' ');
    final pattern = switch (platform) {
      GigPlatform.lyft => throw StateError('handled above'),
      GigPlatform.uber => RegExp(
        r'\bpicking\s+up\b|\bwaiting\s+for\s+rider\b|'
        r'\bstart\s+(?:uber\s*)?(?:x|xl|comfort|share|pool|green|pet|premier|black|connect)\b|'
        r'\bdropping\s+off\b|'
        r'\bcomplete\s+(?:uber\s*)?(?:x|xl|comfort|share|pool|green|pet|premier|black|connect)\b',
        caseSensitive: false,
      ),
      GigPlatform.hopp => throw StateError('handled above'),
      GigPlatform.uberEats ||
      GigPlatform.doorDash ||
      GigPlatform.instacart ||
      GigPlatform.skip => RegExp(r'(?!)'),
    };
    return pattern.hasMatch(joined);
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
    final pickupKm = _legKm(legs.first);
    var tripMin = 0.0;
    var tripKm = 0.0;
    for (final leg in legs.skip(1)) {
      tripMin += double.tryParse(leg.group(1)!) ?? 0;
      tripKm += _legKm(leg);
    }
    if (pickupKm + tripKm <= 0) return null;
    return (
      pickupKm: pickupKm,
      pickupMin: pickupMin,
      tripKm: tripKm,
      tripMin: tripMin,
    );
  }

  static ({double tripKm, double tripMin})? foldScheduledLeg(RegExpMatch leg) {
    final tripMin = double.tryParse(leg.group(1)!) ?? 0;
    final tripKm = _legKm(leg);
    if (tripKm <= 0 || tripMin <= 0) return null;
    return (tripKm: tripKm, tripMin: tripMin);
  }

  static double _legKm(RegExpMatch leg) {
    final value = double.tryParse(leg.group(2)!) ?? 0;
    final unit = leg.group(3)?.toLowerCase();
    return unit == 'mi' || unit?.startsWith('mile') == true
        ? value * DistanceUnit.kilometresPerMile
        : value;
  }
}
