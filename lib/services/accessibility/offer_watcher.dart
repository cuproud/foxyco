import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/offer.dart';
import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
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
  GigPlatform? _shownPlatform;

  /// When the current pill was shown, to enforce a minimum visible time
  /// ([minVisible]) so a card that vanishes almost immediately can't blink the
  /// pill away before the driver can read it.
  DateTime? _shownAt;

  /// Pending "the offer card is gone" clear. Armed only once the card's payout
  /// has left the screen (see [_onRead]), never on a mere failed full-parse. It
  /// rides out the one-frame gap at a screen transition; any card frame cancels
  /// it.
  Timer? _clearTimer;

  /// Outcome inferred from the screen that replaced the card: browse/home/map →
  /// the driver passed ([OfferOutcome.missed]); an explicit in-trip screen →
  /// taken ([OfferOutcome.taken]). Heuristic — see [OfferOutcome].
  ///
  /// Deliberately NOT tied to the pill (see [_inferOutcome]). Held for
  /// [clearGrace] before it is applied so a card frame coming right back can
  /// cancel a premature verdict.
  OfferOutcome _pendingOutcome = OfferOutcome.unknown;
  GigPlatform? _pendingOutcomePlatform;
  Timer? _outcomeTimer;

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

  /// How long the watched apps may stay SILENT before we assume the driver left
  /// them and drop the pill.
  ///
  /// The accessibility service is package-scoped in res/xml (AUDIT #1 Play
  /// review, AUDIT #4 battery), so the moment any other app is foregrounded
  /// Android delivers us nothing at all — [_onRead] stops firing, the normal
  /// "card left the screen" path never arms, and the pill sat there forever
  /// (device 2026-07-24: pill shown from a background gig app never closed).
  /// Silence is the only signal a scoped service gets, so we time it.
  ///
  /// Not a max lifetime: any frame from a watched app resets it. Inside Uber /
  /// Hopp / Lyft the event stream machine-guns (that's why [AccessibilityWatcher]
  /// debounces at all), so a card the driver is still reading keeps the pill up
  /// indefinitely. Mutable so tests can shrink it, and so this stays one number
  /// to retune if a real card ever goes this long without emitting a frame.
  @visibleForTesting
  static Duration idleTimeout = const Duration(seconds: 7);

  /// Fires [idleTimeout] after the last frame from a watched app. Armed only
  /// while a pill is up; cancelled with it.
  Timer? _idleTimer;

  /// Production logs need enough shape information to retune a parser without
  /// storing rider names or addresses. Identical partial frames can arrive
  /// several times a second, so write the same signature at most once per
  /// interval; parse-health counters still record every miss in memory.
  String? _lastMissSignature;
  DateTime? _lastMissLoggedAt;
  int _suppressedMisses = 0;
  static const _missLogInterval = Duration(seconds: 10);

  @override
  Offer? build() {
    _sub = _watcher.reads().listen(
      _onRead,
      onError: (Object e) {
        if (kDebugMode) debugPrint('FoxyCo[watch] read error: $e');
        ref.read(foxLogProvider).log('error', 'read stream: $e');
      },
    );
    ref.onDispose(() {
      _sub?.cancel();
      _clearTimer?.cancel();
      _idleTimer?.cancel();
      _outcomeTimer?.cancel();
    });
    return null;
  }

  /// A watched app just sent a frame — the driver is still in it, so restart the
  /// silence clock. No-op while no pill is up; there is nothing to time out.
  void _touchIdle(GigPlatform platform) {
    if (_shownKey == null || _shownPlatform != platform) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      if (kDebugMode) {
        debugPrint('FoxyCo[watch] clear: watched apps silent, driver left');
      }
      ref.read(foxLogProvider).log('overlay', 'pill cleared — left gig app');
      _clearNow();
    });
  }

  AccessibilityWatcher get _watcher => ref.read(accessibilityWatcherProvider);

  /// Stable identity for an offer: same card ⇒ same key. Rounded km so tiny
  /// live-distance jitter doesn't count as a new offer.
  static String _keyFor(Offer o) =>
      '${o.platform.name}|${o.payout}|${o.totalKm.toStringAsFixed(1)}';

  void _onRead(ScreenRead read) {
    // Trace EVERY read so a broken parse is diagnosable from logcat. Debug
    // builds only — a11y events fire many times a second over a whole shift,
    // and a per-read log line is real string churn + disk flushes in release.
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] read pkg=${read.packageName} '
        'nodes=${read.texts.length} :: ${read.texts.join(" | ")}',
      );
      ref
          .read(foxLogProvider)
          .log(
            'watch',
            'read pkg=${read.packageName} nodes=${read.texts.length}',
          );
    }

    // Respect pause/blocked — don't score while the driver has it off.
    if (ref.read(dashboardProvider).status != WatchStatus.watching) {
      if (kDebugMode) debugPrint('FoxyCo[watch] drop: not watching');
      return;
    }

    final parser = ref
        .read(parserRegistryProvider)
        .forPackage(read.packageName);
    if (parser == null) return; // not an app we read (noise from other apps)

    // Only the app that owns the current pill may keep its idle timer alive.
    // Background events from another watched app are unrelated.
    _touchIdle(parser.platform);

    // A watched app sent a frame with ZERO readable text. Uber's offer card is
    // suspected to render on canvas/Compose with no a11y text (device
    // 2026-07-18: Hopp/Lyft parse, Uber never does) — count these so Settings'
    // parser health can say "unreadable, needs OCR" instead of a silent blank.
    if (read.texts.isEmpty) {
      ref
          .read(parseHealthProvider.notifier)
          .recordTextlessFrame(parser.platform);
      return;
    }

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
      // Outcome first, and independent of whether a pill is up: by the time the
      // driver has switched apps and set up navigation the pill is long gone
      // (idle timeout), and everything below this point is pill bookkeeping
      // that early-returns when nothing is showing.
      _inferOutcome(parser.platform, read.texts);

      if (_shownKey == null) {
        // Nothing showing. Usually browse/home noise — but a frame carrying the
        // takeable-offer affordance was very likely a REAL offer card we failed
        // to read. Count it: misses with zero successes = stale selectors
        // (surfaced as "Parser health" in Settings).
        if (ParserPatterns.hasAcceptAction(read.texts)) {
          ref
              .read(parseHealthProvider.notifier)
              .recordCardMiss(parser.platform);
          _logCardMiss(parser, read.texts);
        }
        if (kDebugMode) debugPrint('FoxyCo[watch] drop: parse null (low conf)');
        return; // nothing showing — browse/home noise, not a lost card
      }
      // An event from one app must never clear another app's current pill.
      if (_shownPlatform != parser.platform) return;

      final joined = read.texts.join(' ');
      final accepted = ParserPatterns.looksLikeAcceptedTrip(
        parser.platform,
        read.texts,
      );
      final onBrowse = ParserPatterns.looksLikeBrowse(joined);
      if (!accepted &&
          !onBrowse &&
          ParserPatterns.looksLikeOfferCard(read.texts)) {
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
        final delay = (!accepted && !onBrowse && floorLeft > clearGrace)
            ? floorLeft
            : clearGrace;
        _clearTimer = Timer(delay, _clearNow);
        if (kDebugMode) {
          debugPrint(
            'FoxyCo[watch] clear armed '
            '(accepted=$accepted, browse=$onBrowse)',
          );
        }
      }
      return; // fail safe — show nothing rather than a wrong verdict
    }

    // A real offer parsed: whatever transient null we may have seen, the card is
    // on screen, so cancel any pending "offer left" clear — and any pending
    // outcome, which would otherwise land on THIS offer instead of the previous
    // one (the log is newest-first).
    _clearTimer?.cancel();
    _clearTimer = null;
    _cancelPendingOutcome();

    // Flicker guard: the same offer card re-fires events constantly. Only push a
    // pill when the offer actually changes; identical re-parses are no-ops.
    final key = _keyFor(offer);
    if (key == _shownKey) return;

    final settings = ref.read(settingsProvider);
    // Driver turned this app off in Settings → ignore its offers entirely.
    if (!settings.watches(offer.platform)) return;

    // Score by the driver's chosen rate mode ($/km or $/hr; falls back to
    // $/km when an offer carries no minutes).
    final verdict = ref
        .read(decisionEngineProvider)
        .scoreOffer(offer, settings);
    if (verdict == Verdict.unknown) return;

    _shownKey = key;
    _shownPlatform = offer.platform;
    _shownAt = DateTime.now();
    _touchIdle(offer.platform); // pill is up now — start the silence clock
    state = offer; // expose the latest parsed offer (debug / future tally)
    // A successful parse also proves this platform's selectors still fit —
    // clears any card-miss streak (Settings "Parser health").
    ref.read(parseHealthProvider.notifier).recordParse(offer.platform);
    ref
        .read(foxLogProvider)
        .log(
          'parse',
          '${offer.platform.label} \$${offer.payout} ${offer.totalKm}km → $verdict',
        );
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] ${offer.platform.label} \$${offer.payout} '
        '${offer.totalKm}km → $verdict',
      );
    }

    // Log the scored offer — this drives the dashboard tally, "Last offer"
    // ticket, and History. Real data only: demo pills never pass through here.
    ref
        .read(offerLogProvider.notifier)
        .record(
          OfferSummary(
            platform: offer.platform,
            verdict: verdict,
            payout: offer.payout,
            bonus: offer.bonus,
            pickupKm: offer.pickupKm,
            totalKm: offer.totalKm,
            totalMinutes: offer.totalMinutes,
            seenAt: DateTime.now(),
            category: offer.category,
            isQueued: offer.isQueued,
          ),
        );

    ref.read(overlayControllerProvider.notifier).showFromOffer(offer, verdict);
  }

  /// Stamp taken/missed onto [platform]'s most recent unresolved offer from
  /// whatever that app is showing NOW — regardless of whether its pill is still
  /// up.
  ///
  /// The pill is short-lived by design (5 s floor, 7 s [idleTimeout] once the
  /// app goes quiet), but accepting is slow: the driver taps Accept inside the
  /// gig app, switches to it, and sets up navigation. The in-trip screen that
  /// proves the accept therefore usually arrives long after the pill died, and
  /// with `_shownKey` already null every later frame used to be dropped as
  /// browse noise — so real accepted Uber and Lyft trips logged as not taken
  /// (device 2026-08-06). Outcome must outlive the pill.
  ///
  /// [OfferLog.markLatestPlatformOutcome] bounds this: same platform, still
  /// `unknown`, seen within its dedupe window. So a stale screen cannot invent
  /// an outcome and a later screen cannot rewrite one.
  void _inferOutcome(GigPlatform platform, List<String> texts) {
    if (!ref.read(settingsProvider).trackOutcomes) return;
    // Card hallmarks mean the offer is still on screen — a half-rendered frame,
    // not a decision. Cancel anything armed from the previous frame.
    if (ParserPatterns.looksLikeOfferCard(texts)) {
      if (_pendingOutcomePlatform == platform) _cancelPendingOutcome();
      return;
    }
    final outcome = ParserPatterns.looksLikeAcceptedTrip(platform, texts)
        ? OfferOutcome.taken
        : ParserPatterns.looksLikeBrowse(texts.join(' '))
        ? OfferOutcome.missed
        : OfferOutcome.unknown;
    if (outcome == OfferOutcome.unknown) return;
    if (_shownPlatform != platform) {
      // No live pill of ours for this app, so there is no card that could flick
      // back and make this verdict premature. Stamp it now.
      _cancelPendingOutcome();
      _pendingOutcome = outcome;
      _pendingOutcomePlatform = platform;
      _applyPendingOutcome();
      return;
    }
    if (_outcomeTimer != null &&
        _pendingOutcomePlatform == platform &&
        _pendingOutcome == outcome) {
      return; // already armed by an identical frame — let it run
    }
    _outcomeTimer?.cancel();
    _pendingOutcome = outcome;
    _pendingOutcomePlatform = platform;
    _outcomeTimer = Timer(clearGrace, _applyPendingOutcome);
  }

  void _cancelPendingOutcome() {
    _outcomeTimer?.cancel();
    _outcomeTimer = null;
    _pendingOutcome = OfferOutcome.unknown;
    _pendingOutcomePlatform = null;
  }

  void _applyPendingOutcome() {
    final platform = _pendingOutcomePlatform;
    final outcome = _pendingOutcome;
    _cancelPendingOutcome();
    if (platform == null || outcome == OfferOutcome.unknown) return;
    ref
        .read(offerLogProvider.notifier)
        .markLatestPlatformOutcome(platform, outcome);
    ref
        .read(foxLogProvider)
        .log('outcome', '${platform.label} offer inferred ${outcome.name}');
  }

  void _logCardMiss(OfferParser parser, List<String> texts) {
    final joined = texts.join(' ');
    final signature =
        '${parser.platform.name}|'
        'payout=${ParserPatterns.findPayout(texts) != null}|'
        'legs=${ParserPatterns.leg.allMatches(joined).length}|'
        'browse=${ParserPatterns.looksLikeBrowse(joined)}|'
        'scheduled=${ParserPatterns.looksLikeScheduledRideList(joined)}';
    final now = DateTime.now();
    if (signature == _lastMissSignature &&
        _lastMissLoggedAt != null &&
        now.difference(_lastMissLoggedAt!) < _missLogInterval) {
      _suppressedMisses++;
      return;
    }

    final repeated = signature == _lastMissSignature && _suppressedMisses > 0
        ? ' repeats=${_suppressedMisses + 1}'
        : '';
    _lastMissSignature = signature;
    _lastMissLoggedAt = now;
    _suppressedMisses = 0;
    ref
        .read(foxLogProvider)
        .log(
          'parse',
          'MISS card-like frame ${parser.platform.label} '
              '${signature.substring(signature.indexOf('|') + 1)} '
              'nodes=${texts.length}$repeated',
        );
  }

  /// The offer stayed gone for the whole grace window — really clear now.
  /// Forget what we showed (so the same offer reappearing shows again) and drop
  /// the pill back to the bubble. Outcome is NOT stamped here: it now runs on
  /// its own clock in [_inferOutcome], because the screen that proves the
  /// accept usually arrives well after the pill is gone.
  void _clearNow() {
    _clearTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_shownKey == null) return;
    _shownKey = null;
    _shownPlatform = null;
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
