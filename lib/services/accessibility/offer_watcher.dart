import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/offer.dart';
import '../../domain/offer_summary.dart';
import '../../domain/verdict.dart';
import '../../parser/offer_parser.dart';
import '../../parser/parser_registry.dart';
import '../../ui/home/dashboard_controller.dart';
import '../../ui/home/dashboard_state.dart';
import '../../ui/overlay/overlay_controller.dart';
import '../../ui/settings/settings_controller.dart';
import '../fox_log.dart';
import '../offer_log.dart';
import '../parse_health.dart';
import 'accessibility_watcher.dart';

/// DI seams so tests can swap fakes for the real plugin wrapper / engine.
final parserRegistryProvider = Provider<ParserRegistry>(
  (ref) => const ParserRegistry(),
);
final decisionEngineProvider = Provider<DecisionEngine>(
  (ref) => const DecisionEngine(),
);

/// The M3 pipeline, main-isolate side (docs/ARCHITECTURE "Data flow"):
///
///   AccessibilityWatcher → ParserRegistry → DecisionEngine → OverlayService
///
/// Listens to screen reads from the watched apps, picks the platform's parser,
/// scores the [Offer] against the driver's live [Thresholds], and pushes the
/// verdict to the overlay pill. Fails safe at every hop: an unhandled package,
/// a low-confidence parse, or a paused engine simply shows nothing — never a
/// confident wrong verdict (AUDIT #3).
///
/// Gating: only forwards while the dashboard is `watching`. Pause (Home button
/// or bubble long-press) flips the status and the next read is dropped here, so
/// we don't tear the accessibility stream down and back up on every toggle.
class OfferWatcher extends Notifier<Offer?> {
  StreamSubscription<ScreenRead>? _sub;

  /// Signature of the offer currently on the pill, so we don't re-show it. The
  /// same offer card re-fires accessibility events constantly (map pans, a "1
  /// stop" chip animates) — re-pushing an identical pill each time resizes the
  /// overlay window on every event and looks like violent flicker. Show once;
  /// the pill stays until the offer card leaves the screen (see [_onRead]).
  /// Reset when the offer changes or the card is gone.
  String? _shownKey;

  /// When the current pill was shown, to enforce a minimum visible time
  /// ([minVisible]) so a card that vanishes almost immediately can't blink the
  /// pill away before the driver can read it.
  DateTime? _shownAt;

  /// Pending "the offer card is gone" clear. Armed only once the card's payout
  /// has left the screen (see [_onRead]), never on a mere failed full-parse. It
  /// rides out the one-frame gap at a screen transition; any card frame cancels
  /// it.
  Timer? _clearTimer;

  /// How long to wait before dropping the pill once the card looks gone. Kept
  /// short: on a browse/home screen the card has DEFINITELY left (offers never
  /// carry browse markers), so we only need to coalesce a frame or two, not
  /// stall. (A residual lag after this is the overlay engine waking from idle to
  /// process the clear message — a plugin characteristic, worse in debug.)
  /// Mutable so tests can shrink it.
  @visibleForTesting
  static Duration clearGrace = const Duration(milliseconds: 500);

  /// Floor on how long a pill stays visible once shown, even if the card seems
  /// to vanish right away — so a flaky frame can't blink it out before it's
  /// readable. A positively-identified browse/home screen (the driver accepted /
  /// declined / dismissed) bypasses this and clears promptly. Mutable for tests.
  @visibleForTesting
  static Duration minVisible = const Duration(seconds: 5);

  @override
  Offer? build() {
    _sub = _watcher.reads().listen(_onRead, onError: (Object e) {
      if (kDebugMode) debugPrint('FoxyCo[watch] read error: $e');
      ref.read(foxLogProvider).log('error', 'read stream: $e');
    });
    ref.onDispose(() {
      _sub?.cancel();
      _clearTimer?.cancel();
    });
    return null;
  }

  AccessibilityWatcher get _watcher => ref.read(accessibilityWatcherProvider);

  /// Stable identity for an offer: same card ⇒ same key. Rounded km so tiny
  /// live-distance jitter doesn't count as a new offer.
  static String _keyFor(Offer o) =>
      '${o.platform.name}|${o.payout}|${o.totalKm.toStringAsFixed(1)}';

  void _onRead(ScreenRead read) {
    // Trace EVERY read so a broken parse is diagnosable from logcat, not just a
    // successful one. Strip before release (see completion doc loose ends).
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] read pkg=${read.packageName} '
        'nodes=${read.texts.length} :: ${read.texts.join(" | ")}',
      );
    }
    ref
        .read(foxLogProvider)
        .log('watch', 'read pkg=${read.packageName} nodes=${read.texts.length}');

    // Respect pause/blocked — don't score while the driver has it off.
    if (ref.read(dashboardProvider).status != WatchStatus.watching) {
      if (kDebugMode) debugPrint('FoxyCo[watch] drop: not watching');
      return;
    }

    final parser = ref.read(parserRegistryProvider).forPackage(read.packageName);
    if (parser == null) return; // not an app we read (noise from other apps)

    final offer = parser.parse(read.texts);
    if (offer == null) {
      // The full parse failed. Two very different situations look identical
      // here — a partial frame *while the card is still up* (legs half-rendered,
      // a map pan behind the card, the Accept/Match button momentarily missing
      // from the a11y tree) vs. the card being *gone* (accepted / declined /
      // dismissed → app back on the map). Gating on the affordance was too
      // fragile: device logs showed Hopp drop the button (and legs) from a frame
      // while `$5.20` was STILL on screen, clearing the pill under a live card.
      //
      // Neither the payout NOR the affordance is reliable on its own — device
      // logs showed Hopp drop the button while `$5.20` stayed, and Lyft drop the
      // payout leaving a lone "Accept". Gating on either one clears the pill
      // mid-read when that field flickers out. So invert it: only a screen that
      // POSITIVELY looks like browse/home/offline/map ([looksLikeBrowse]) means
      // the card really left (declined / accepted / dismissed / timed out).
      // Every offer card is free of those markers, and any ambiguous partial
      // frame — a lone button, payout-only, a half-rendered tree — is treated as
      // "still on the card" so the pill holds.
      if (_shownKey == null) {
        // Nothing showing. Usually browse/home noise — but a frame carrying the
        // takeable-offer affordance was very likely a REAL offer card we failed
        // to read. Count it: misses with zero successes = stale selectors
        // (surfaced as "Parser health" in Settings).
        if (ParserPatterns.hasAcceptAction(read.texts)) {
          ref
              .read(parseHealthProvider.notifier)
              .recordCardMiss(parser.platform);
          ref
              .read(foxLogProvider)
              .log('parse', 'MISS card-like frame ${parser.platform.label}');
        }
        if (kDebugMode) debugPrint('FoxyCo[watch] drop: parse null (low conf)');
        return; // nothing showing — browse/home noise, not a lost card
      }
      final joined = read.texts.join(' ');
      final onBrowse = ParserPatterns.looksLikeBrowse(joined);
      if (!onBrowse && ParserPatterns.looksLikeOfferCard(read.texts)) {
        // A partial frame of the still-present card. Keep the pill and drop any
        // pending clear so a run of partials can't age it out.
        _clearTimer?.cancel();
        _clearTimer = null;
        return;
      }
      // Browse/home screen, or a screen with NO card hallmark at all (e.g. an
      // in-trip nav screen after accept). The card is gone → clear. On a browse
      // screen clear promptly ([clearGrace]); otherwise hold to [minVisible]
      // first so a stray blank frame can't blink the pill out before it's read.
      if (_clearTimer == null) {
        final shownFor = DateTime.now().difference(_shownAt ?? DateTime.now());
        final floorLeft = minVisible - shownFor;
        final delay = (!onBrowse && floorLeft > clearGrace) ? floorLeft : clearGrace;
        _clearTimer = Timer(delay, _clearNow);
        if (kDebugMode) debugPrint('FoxyCo[watch] clear armed (card left, browse=$onBrowse)');
      }
      return; // fail safe — show nothing rather than a wrong verdict
    }

    // A real offer parsed: whatever transient null we may have seen, the card is
    // on screen, so cancel any pending "offer left" clear.
    _clearTimer?.cancel();
    _clearTimer = null;

    // Flicker guard: the same offer card re-fires events constantly. Only push a
    // pill when the offer actually changes; identical re-parses are no-ops.
    final key = _keyFor(offer);
    if (key == _shownKey) return;

    final settings = ref.read(settingsProvider);
    // Driver turned this app off in Settings → ignore its offers entirely.
    if (!settings.watches(offer.platform)) return;

    // Score by the driver's chosen rate mode ($/km or $/hr; falls back to
    // $/km when an offer carries no minutes).
    final verdict = ref.read(decisionEngineProvider).scoreOffer(
      offer,
      settings,
    );
    if (verdict == Verdict.unknown) return;

    _shownKey = key;
    _shownAt = DateTime.now();
    state = offer; // expose the latest parsed offer (debug / future tally)
    // A successful parse also proves this platform's selectors still fit —
    // clears any card-miss streak (Settings "Parser health").
    ref.read(parseHealthProvider.notifier).recordParse(offer.platform);
    ref.read(foxLogProvider).log(
        'parse', '${offer.platform.label} \$${offer.payout} ${offer.totalKm}km → $verdict');
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] ${offer.platform.label} \$${offer.payout} '
        '${offer.totalKm}km → $verdict',
      );
    }

    // Log the scored offer — this drives the dashboard tally, "Last offer"
    // ticket, and History. Real data only: demo pills never pass through here.
    ref.read(offerLogProvider.notifier).record(
      OfferSummary(
        platform: offer.platform,
        verdict: verdict,
        payout: offer.payout,
        pickupKm: offer.pickupKm,
        totalKm: offer.totalKm,
        totalMinutes: offer.totalMinutes,
        seenAt: DateTime.now(),
      ),
    );

    ref.read(overlayControllerProvider.notifier).showFromOffer(offer, verdict);
  }

  /// The offer stayed gone for the whole grace window — really clear now. Forget
  /// what we showed (so the same offer reappearing shows again) and drop the pill
  /// back to the bubble.
  void _clearNow() {
    _clearTimer = null;
    if (_shownKey == null) return;
    _shownKey = null;
    _shownAt = null;
    state = null;
    ref.read(overlayControllerProvider.notifier).clearOffer();
    ref.read(foxLogProvider).log('overlay', 'pill cleared — offer left screen');
    if (kDebugMode) debugPrint('FoxyCo[watch] clear: offer left screen');
  }
}

final offerWatcherProvider = NotifierProvider<OfferWatcher, Offer?>(
  OfferWatcher.new,
);
