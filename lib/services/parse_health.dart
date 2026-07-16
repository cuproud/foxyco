import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform.dart';

/// Per-platform parse health for the current session.
///
/// Selectors WILL break when a gig app updates its layout (AUDIT "parser
/// fragility") — and the failure mode is silence: the pill just stops
/// appearing, indistinguishable from a slow night. This counter makes that
/// visible: the watcher reports every successful parse and every frame that
/// LOOKED like an offer card (accept affordance present) but failed the full
/// parse. Lots of card-like misses with zero successes = the parser is likely
/// stale for that app.
///
/// In-memory only, resets each app start — health is a "right now" question;
/// persisting stale counts would only mislead.
class PlatformHealth {
  /// Full parses that produced an offer this session.
  final int parsed;

  /// Card-like frames (accept/match affordance on screen) whose full parse
  /// failed. Partial frames make SOME misses normal even when healthy — it's
  /// misses with [parsed] still at zero that signal a broken parser.
  final int cardMisses;

  const PlatformHealth({this.parsed = 0, this.cardMisses = 0});

  /// Enough card-like frames to be sure offers are arriving, yet not one
  /// parsed → the selectors are likely stale for this app's current layout.
  static const brokenAfterMisses = 10;
  bool get likelyBroken => parsed == 0 && cardMisses >= brokenAfterMisses;
}

/// Session parse-health tally, keyed by platform. The M3 pipeline reports
/// into this; Settings renders it as the "Parser health" section.
class ParseHealth extends Notifier<Map<GigPlatform, PlatformHealth>> {
  @override
  Map<GigPlatform, PlatformHealth> build() => const {};

  PlatformHealth _of(GigPlatform p) => state[p] ?? const PlatformHealth();

  void recordParse(GigPlatform p) {
    final h = _of(p);
    state = {...state, p: PlatformHealth(parsed: h.parsed + 1)};
    // A success also proves the parser works — reset the miss streak so a
    // burst of partial frames earlier in the shift can't trip the flag later.
  }

  void recordCardMiss(GigPlatform p) {
    final h = _of(p);
    state = {
      ...state,
      p: PlatformHealth(parsed: h.parsed, cardMisses: h.cardMisses + 1),
    };
  }
}

final parseHealthProvider =
    NotifierProvider<ParseHealth, Map<GigPlatform, PlatformHealth>>(
  ParseHealth.new,
);
