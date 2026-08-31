import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/offer.dart';
import '../../domain/offer_summary.dart';
import '../../domain/scoring_snapshot.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../parser/offer_parser.dart';
import '../../parser/parser_registry.dart';
import '../../parser/uber_parser.dart';
import '../../ui/home/dashboard_controller.dart';
import '../../ui/home/dashboard_state.dart';
import '../../ui/overlay/overlay_controller.dart';
import '../../ui/settings/settings_controller.dart';
import '../fox_log.dart';
import '../offer_log.dart';
import '../ocr/ocr_capture.dart';
import '../parse_health.dart';
import '../verdict_voice.dart';
import 'accessibility_watcher.dart';
import 'route_shadow_diagnostics.dart';

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
  late final RouteShadowDiagnostics _routeShadow = RouteShadowDiagnostics(
    log: (message) => ref.read(foxLogProvider).log('route-shadow', message),
  );

  /// Signature of the offer currently on the pill, so we don't re-show it. The
  /// same offer card re-fires accessibility events constantly (map pans, a "1
  /// stop" chip animates) — re-pushing an identical pill each time resizes the
  /// overlay window on every event and looks like violent flicker. Show once;
  /// the pill stays until the offer card leaves the screen (see [_onRead]).
  /// Reset when the offer changes or the card is gone.
  String? _shownKey;
  GigPlatform? _shownPlatform;
  int? _shownWindowId;
  final Set<String> _suppressedKeys = <String>{};

  bool _confirmedCardLeft = false;

  /// Pending "the offer card is gone" clear. Armed only once the card's payout
  /// has left the screen (see [_onRead]), never on a mere failed full-parse. It
  /// rides out the one-frame gap at a screen transition; any card frame cancels
  /// it.
  Timer? _clearTimer;
  Timer? _expiryTimer;
  int _voiceGeneration = 0;

  /// Let the pill show and allow one short run of stabilizing frames before
  /// speaking. Generation checks suppress queued speech when this offer is
  /// replaced, cleared, or re-evaluated.
  @visibleForTesting
  static Duration voiceStability = const Duration(milliseconds: 100);

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

  /// Exact logged row awaiting an outcome for each app. Accessibility repeats
  /// trip screens; binding the evidence to a row makes those repeats idempotent.
  final Map<GigPlatform, OfferSummary> _outcomeCandidates = {};

  /// A trip screen already visible behind a new offer cannot prove that the
  /// new offer was accepted. Only an explicit queued confirmation can.
  final Set<GigPlatform> _activeTripScreens = {};
  final Map<GigPlatform, OfferSummary> _offersShownDuringTrip = {};

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
  /// readable, including after a fast accept, decline, dismissal, or timeout.
  /// Mutable for tests.
  @visibleForTesting
  static Duration maxVisible = const Duration(seconds: 5);

  /// Legacy test/config name retained for source compatibility. The lifecycle
  /// is governed by [maxVisible], never by a resettable minimum floor.
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

  bool _ocrBusy = false;
  bool _ocrMatched = false;
  int _accessibilityOfferGeneration = 0;
  bool _uberOcrCardActive = false;
  String? _pendingOcrCorrectionKey;
  String? _pendingSuspiciousOcrKey;
  Offer? _lastUberOffer;
  DateTime? _lastUberOfferAt;
  DateTime? _lastOcrAt;
  Timer? _ocrRetryTimer;
  String? _pendingOcrPackage;
  ScreenRead? _coveredRead;
  DateTime? _coveredReadAt;

  @visibleForTesting
  static Duration ocrCooldown = const Duration(milliseconds: 1500);
  @visibleForTesting
  static Duration coveredOfferFreshness = const Duration(seconds: 15);
  static const _noUberCard = '__FOXYCO_NO_UBER_CARD__';
  static final _droppedDecimalPayout = RegExp(r'\$\s*\d{3,}(?![\d.])');
  static final _droppedDecimalDistance = RegExp(
    r'\(\s*\d{3,}\s*(?:km|mi|miles?)\s*\)',
    caseSensitive: false,
  );
  static final _uberOcrEvidence = RegExp(
    r'\buber\s*(?:x|xl|share|comfort|green|pet|premier|black|connect|eats)\b',
    caseSensitive: false,
  );

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
      _expiryTimer?.cancel();
      _idleTimer?.cancel();
      _outcomeTimer?.cancel();
      _ocrRetryTimer?.cancel();
      _voiceGeneration++;
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

  /// Stable identity for an offer while its card is active. Category, bonus,
  /// and queue labels can appear a frame later in Lyft's accessibility tree;
  /// they enrich the card but do not make it a second offer.
  static String _keyFor(Offer o) =>
      '${o.platform.name}|${o.payout}|${o.pickupKm.toStringAsFixed(1)}|'
      '${o.totalKm.toStringAsFixed(1)}|${o.totalMinutes.toStringAsFixed(1)}|'
      '${o.deliveryCount}';

  static bool _sameRoute(Offer a, Offer b) =>
      a.platform == b.platform &&
      a.pickupKm == b.pickupKm &&
      a.totalKm == b.totalKm &&
      a.totalMinutes == b.totalMinutes &&
      a.deliveryCount == b.deliveryCount;

  void _cancelPendingVoice(String reason) {
    _voiceGeneration++;
    if (kDebugMode) {
      debugPrint('FoxyCo[voice] cancelled reason=$reason');
      ref.read(foxLogProvider).log('voice', 'cancelled reason=$reason');
    }
  }

  void _queueVoice({
    required Future<bool> pillShown,
    required String key,
    required GigPlatform platform,
    required Verdict verdict,
  }) {
    final generation = ++_voiceGeneration;
    if (kDebugMode) {
      debugPrint('FoxyCo[voice] queued key=$key verdict=$verdict');
      ref.read(foxLogProvider).log('voice', 'queued key=$key verdict=$verdict');
    }
    unawaited(() async {
      if (!await pillShown) return;
      await Future<void>.delayed(voiceStability);
      if (generation != _voiceGeneration ||
          _shownKey != key ||
          _shownPlatform != platform ||
          ref.read(dashboardProvider).status != WatchStatus.watching) {
        return;
      }
      final current = ref.read(settingsProvider);
      final allowed =
          current.voiceVerdictEnabled &&
          ((verdict == Verdict.good && current.announceGoodOffers) ||
              (verdict == Verdict.ok && current.announceOkOffers));
      if (!allowed) return;
      if (kDebugMode) {
        debugPrint('FoxyCo[voice] speaking key=$key verdict=$verdict');
        ref
            .read(foxLogProvider)
            .log('voice', 'spoken key=$key verdict=$verdict');
      }
      await ref
          .read(verdictVoiceProvider)
          .speak(verdict, current.voiceCooldownSeconds);
    }());
  }

  void _onRead(ScreenRead read) {
    // Trace EVERY read so a broken parse is diagnosable from logcat. Debug
    // builds only — a11y events fire many times a second over a whole shift,
    // and a per-read log line is real string churn + disk flushes in release.
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] read pkg=${read.packageName} '
        'nodes=${read.texts.length} source=${read.source.name}',
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

    final registry = ref.read(parserRegistryProvider);
    if (read.source == CaptureSource.accessibility && read.isActive) {
      final source = registry.forPackage(read.packageName);
      if (source != null) {
        if (ParserPatterns.looksLikeAcceptedTrip(source.platform, read.texts)) {
          _activeTripScreens.add(source.platform);
        } else if (ParserPatterns.looksLikeBrowse(read.texts.join(' '))) {
          // Offer and partial frames can cover an ongoing trip. Keep that trip
          // active until the app positively returns to browse/home; otherwise
          // the underlying trip screen falsely accepts the covered offer.
          _activeTripScreens.remove(source.platform);
        }
      }
    }
    OfferParser? parser;
    Offer? offer;
    var parsedTexts = read.texts;
    ScreenWindow? offerWindow;
    ScreenWindow? topCardWindow;
    if (read.source == CaptureSource.ocr) {
      _ocrMatched = false;
      final settings = ref.read(settingsProvider);
      if (!settings.ocrEnabled || !settings.watches(GigPlatform.uber)) return;
      if (read.texts.contains(_noUberCard)) {
        if (_uberOcrCardActive) {
          _uberOcrCardActive = false;
          _clearNow(reason: 'Uber card left screen');
          _restoreCoveredRead();
        }
        return;
      }
      parser = registry.forPackage(ParserRegistry.uberPackage);
      if (parser == null) return;
      final cardTexts = UberParser.isolateOcrCard(read.texts);
      parsedTexts = cardTexts;
      final joined = cardTexts.join(' ');
      offer = _uberOcrEvidence.hasMatch(joined)
          ? parser.parse(cardTexts)
          : null;
      // OCR is fallback evidence for offers only. It must never drive card-exit
      // or outcome inference from an incomplete screenshot.
      if (offer == null) {
        if (ParserPatterns.hasOfferAction(cardTexts) &&
            !ParserPatterns.looksLikeBrowse(joined)) {
          ref
              .read(parseHealthProvider.notifier)
              .recordCardMiss(parser.platform);
          _logCardMiss(parser, cardTexts, source: read.source);
        }
        return;
      }
      _ocrMatched = true;
    } else {
      parser = registry.forPackage(read.packageName);
      final settings = ref.read(settingsProvider);
      // Android scopes events to every supported package, while the in-app
      // selection is narrower. Never let another parser reinterpret a card
      // from a package the driver switched off.
      if (parser != null && !settings.watches(parser.platform)) return;
      final useUberOcr =
          settings.ocrEnabled && parser?.platform == GigPlatform.uber;
      final forceCrossAppOcr =
          kDebugMode && settings.ocrEnabled && settings.ocrTestMode;
      final checkForCoveredUber =
          settings.ocrEnabled && parser?.platform != GigPlatform.uber;
      if (useUberOcr) {
        final joined = read.texts.join(' ');
        final accepted = ParserPatterns.looksLikeAcceptedTrip(
          GigPlatform.uber,
          read.texts,
        );
        final browse = ParserPatterns.looksLikeBrowse(joined);
        final terminal = accepted || (_uberOcrCardActive && browse);
        if (read.isActive &&
            _shownPlatform != null &&
            _shownPlatform != GigPlatform.uber) {
          _clearNow();
        }
        if (read.isActive && terminal) {
          // OCR owns Uber offer economics, but Accessibility still owns card
          // lifecycle and outcomes. Invalidate a screenshot of the card that
          // just left so it cannot resurrect a dismissed offer.
          _accessibilityOfferGeneration++;
          _uberOcrCardActive = false;
          _pendingOcrCorrectionKey = null;
          _pendingSuspiciousOcrKey = null;
        } else if (read.isActive && browse && _ocrBusy) {
          // A browse frame racing an unfinished first capture is ambiguous:
          // discard that old screenshot and let the bounded retry confirm.
          _accessibilityOfferGeneration++;
        }
      } else if (forceCrossAppOcr || checkForCoveredUber) {
        if (read.isActive &&
            parser != null &&
            settings.watches(parser.platform)) {
          // Uber can draw its card over any selected driver app without
          // emitting an Uber Accessibility event. Probe once from the active
          // lower-app frame;
          // only a confirmed Uber card starts the existing lifecycle polling.
          unawaited(_requestOcr(read.packageName));
        }
        // With OCR enabled, Uber offer data comes only from OCR. Test mode may
        // also trigger from another watched app to exercise stacked Uber,
        // but that app keeps its normal low-latency Accessibility parse.
      }
      if (read.texts.isEmpty) {
        if (parser != null) {
          ref
              .read(parseHealthProvider.notifier)
              .recordTextlessFrame(parser.platform);
        }
        if (read.isActive) unawaited(_requestOcr(read.packageName));
        return;
      }

      final topIsTerminal =
          ParserPatterns.looksLikeBrowse(read.texts.join(' ')) ||
          GigPlatform.values.any(
            (platform) =>
                ParserPatterns.looksLikeAcceptedTrip(platform, read.texts),
          );
      final windows = [...read.windows]
        ..sort((a, b) {
          final layer = b.layer.compareTo(a.layer);
          if (layer != 0) return layer;
          final focused = (b.isFocused ? 1 : 0).compareTo(a.isFocused ? 1 : 0);
          if (focused != 0) return focused;
          return (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
        });
      final cardWindows = windows
          .where((window) => ParserPatterns.looksLikeOfferCard(window.texts))
          .toList();
      topCardWindow = cardWindows.firstOrNull;
      final frames = topIsTerminal || windows.isEmpty
          ? [(texts: read.texts, window: null)]
          : cardWindows.isNotEmpty
          ? [(texts: cardWindows.first.texts, window: cardWindows.first)]
          : [
              for (final window in windows)
                (texts: window.texts, window: window),
            ];
      for (final frame in frames) {
        for (final candidate in registry.candidates(read.packageName)) {
          if (!settings.watches(candidate.platform)) continue;
          final parsed = candidate.parse(frame.texts);
          if (parsed != null) {
            parser = candidate;
            offer = parsed;
            parsedTexts = frame.texts;
            offerWindow = frame.window;
            break;
          }
        }
        if (offer != null) break;
      }
    }
    final activeParser = parser;
    if (activeParser == null) return;

    if (read.source == CaptureSource.accessibility &&
        offer?.platform != GigPlatform.uber &&
        offer != null) {
      _coveredRead = read;
      _coveredReadAt = DateTime.now();
      if (_uberOcrCardActive) {
        // The lower card is still alive, but Uber owns the visible pixels.
        // Keep it for restoration and verify Uber's top-card lifecycle by OCR.
        unawaited(_requestOcr(read.packageName));
        return;
      }
    }

    // A selected lower app keeps emitting active map/partial frames while an
    // Uber card is visibly stacked above it. Only OCR can prove that top card
    // left; treating the lower frame as a foreground switch cleared the Uber
    // verdict within milliseconds on device. Complete lower cards were cached
    // above first so the real-device race can restore them after Uber closes.
    if (read.source == CaptureSource.accessibility &&
        _uberOcrCardActive &&
        _shownPlatform == GigPlatform.uber &&
        activeParser.platform != GigPlatform.uber) {
      if (read.isActive) unawaited(_requestOcr(read.packageName));
      return;
    }

    // A confirmed foreground switch must not leave the previous app's offer
    // over the newly active app while its next card frame is still rendering.
    // Ignore background events: watched apps can emit those while another gig
    // app legitimately owns the pill.
    final switchedPlatform =
        read.isActive &&
        _shownPlatform != null &&
        _shownPlatform != activeParser.platform;

    // Only an active window may keep the pill alive. A watched app can keep
    // emitting stale background frames while the driver is in another app.
    if (read.isActive) _touchIdle(activeParser.platform);

    if (offer == null) {
      if (read.source == CaptureSource.ocr) return;
      if (read.isActive &&
          _coveredRead?.packageName == read.packageName &&
          ParserPatterns.looksLikeBrowse(read.texts.join(' '))) {
        _coveredRead = null;
        _coveredReadAt = null;
      }
      if (switchedPlatform) _clearNow();
      if (_shownKey != null &&
          topCardWindow != null &&
          topCardWindow.id != _shownWindowId) {
        _clearNow();
      }
      if (_shownKey == null &&
          read.isActive &&
          ParserPatterns.looksLikeOfferCard(read.texts)) {
        unawaited(_requestOcr(read.packageName));
      }
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
      _inferOutcome(activeParser.platform, read.texts, isActive: read.isActive);

      if (_shownKey == null) {
        // Nothing showing. Usually browse/home noise — but a frame carrying the
        // takeable-offer affordance was very likely a REAL offer card we failed
        // to read. Count it: misses with zero successes = stale selectors
        // (surfaced as "Parser health" in Settings).
        if (ParserPatterns.hasOfferAction(read.texts) &&
            !ParserPatterns.looksLikeBrowse(read.texts.join(' '))) {
          ref
              .read(parseHealthProvider.notifier)
              .recordCardMiss(activeParser.platform);
          _logCardMiss(activeParser, read.texts, source: read.source);
        }
        if (kDebugMode) debugPrint('FoxyCo[watch] drop: parse null (low conf)');
        return; // nothing showing — browse/home noise, not a lost card
      }
      // An event from one app must never clear another app's current pill.
      if (_shownPlatform != activeParser.platform) return;
      // Nor may a stale background frame from the same app clear its pill.
      if (!read.isActive) return;

      final joined = read.texts.join(' ');
      final accepted = ParserPatterns.looksLikeAcceptedTrip(
        activeParser.platform,
        read.texts,
      );
      final onBrowse = ParserPatterns.looksLikeBrowse(joined);
      if (!accepted &&
          ParserPatterns.looksLikeOfferCard(read.texts, onBrowse: onBrowse)) {
        // A partial frame of the still-present card. Keep the pill and drop any
        // pending clear so a run of partials can't age it out. Card hallmarks
        // win over browse chrome: Lyft's reader merges its Ride Finder map and
        // offer window into one frame, so both can legitimately be present.
        _clearTimer?.cancel();
        _clearTimer = null;
        return;
      }
      // Browse/home screen, or a screen with NO card hallmark at all (e.g. an
      // in-trip nav screen after accept). The card is gone → clear. On a browse
      // A confirmed action/disappearance clears within the short grace window.
      if (_clearTimer == null) {
        _clearTimer = Timer(clearGrace, _clearNow);
        if (kDebugMode) {
          debugPrint(
            'FoxyCo[watch] clear armed '
            '(accepted=$accepted, browse=$onBrowse)',
          );
        }
      }
      if (accepted || onBrowse) _confirmedCardLeft = true;
      return; // fail safe — show nothing rather than a wrong verdict
    }

    final key = _keyFor(offer);
    if (read.source == CaptureSource.accessibility && read.isActive) {
      // A lower selected-app card can keep emitting while Uber is visibly
      // stacked above it. Only Uber evidence can invalidate an Uber screenshot.
      if (offer.platform == GigPlatform.uber) _accessibilityOfferGeneration++;
      _pendingOcrCorrectionKey = null;
      _pendingSuspiciousOcrKey = null;
    } else if (read.source == CaptureSource.ocr &&
        read.texts.any(
          (text) =>
              _droppedDecimalPayout.hasMatch(text) ||
              _droppedDecimalDistance.hasMatch(text),
        )) {
      // ML Kit occasionally drops a decimal ('$7.54' -> '$754', or '30.4 km'
      // -> '304 km'). Never score or persist impossible raw OCR economics.
      if (_pendingSuspiciousOcrKey != key) {
        _pendingSuspiciousOcrKey = key;
        _ocrMatched = false;
        ref
            .read(foxLogProvider)
            .log(
              'ocr',
              'suspicious Uber OCR economics held — awaiting confirmation',
            );
        return;
      }
      _ocrMatched = false;
      return;
    } else if (read.source == CaptureSource.ocr &&
        key != _shownKey &&
        ((_shownPlatform == GigPlatform.uber && state != null) ||
            (_lastUberOffer != null &&
                _lastUberOffer!.payout != offer.payout &&
                _sameRoute(_lastUberOffer!, offer) &&
                DateTime.now().difference(_lastUberOfferAt!) <
                    const Duration(seconds: 5)))) {
      // A card animating away can briefly corrupt distance or payout in ML Kit.
      // Keep the live verdict until any changed economics repeat once.
      if (_pendingOcrCorrectionKey != key) {
        _pendingOcrCorrectionKey = key;
        _ocrMatched = false; // request one rate-limited confirmation frame
        ref
            .read(foxLogProvider)
            .log(
              'ocr',
              'conflict held Uber \$${offer.payout} '
                  '${offer.totalKm.toStringAsFixed(1)}km — awaiting confirmation',
            );
        return;
      }
      _pendingOcrCorrectionKey = null;
    } else if (read.source == CaptureSource.ocr) {
      _pendingOcrCorrectionKey = null;
      _pendingSuspiciousOcrKey = null;
    }
    if (read.source == CaptureSource.ocr) _uberOcrCardActive = true;
    if (offer.platform == GigPlatform.uber) {
      _lastUberOffer = offer;
      _lastUberOfferAt = DateTime.now();
    }

    // A real offer parsed: whatever transient null we may have seen, the card is
    // on screen, so cancel any pending "offer left" clear — and any pending
    // outcome, which would otherwise land on THIS offer instead of the previous
    // one (the log is newest-first).
    _clearTimer?.cancel();
    _clearTimer = null;
    if (_shownKey != null) _confirmedCardLeft = false;
    _cancelPendingOutcome();

    // Flicker guard: the same offer card re-fires events constantly. Only push a
    // pill when the offer actually changes; identical re-parses are no-ops.
    if (key == _shownKey) return;
    // Historical suppression only applies after the pill is gone. While a
    // different offer is active, this is a replacement and must win even if
    // its fingerprint appeared earlier in the session.
    if (_shownKey == null && _suppressedKeys.contains(key)) return;

    final settings = ref.read(settingsProvider);
    // Driver turned this app off in Settings → ignore its offers entirely.
    if (!settings.watches(offer.platform)) return;

    // Score by the driver's chosen rate mode ($/km or $/hr; falls back to
    // $/km when an offer carries no minutes).
    final verdict = ref
        .read(decisionEngineProvider)
        .scoreOffer(offer, settings);
    if (verdict == Verdict.unknown) return;

    if (_shownKey != null) {
      _suppressedKeys.add(_shownKey!);
      _cancelPendingVoice('new offer');
    }
    _shownKey = key;
    _shownPlatform = offer.platform;
    _shownWindowId = offerWindow?.id;
    _expiryTimer?.cancel();
    _expiryTimer = Timer(maxVisible, () {
      if (_shownKey != key) return;
      _suppressedKeys.add(key);
      _clearNow(reason: '5 s display timeout');
    });
    _touchIdle(offer.platform); // pill is up now — start the silence clock
    state = offer; // expose the latest parsed offer (debug / future tally)
    // A successful parse also proves this platform's selectors still fit —
    // clears any card-miss streak (Settings "Parser health").
    ref.read(parseHealthProvider.notifier).recordParse(offer.platform);
    ref
        .read(foxLogProvider)
        .log(
          'parse',
          '${offer.platform.label} \$${offer.payout} '
              '${offer.totalKm.toStringAsFixed(1)}km → $verdict '
              'source=${read.source.name}',
        );
    if (kDebugMode) {
      debugPrint(
        'FoxyCo[watch] ${offer.platform.label} \$${offer.payout} '
        '${offer.totalKm.toStringAsFixed(1)}km → $verdict',
      );
    }

    // Log the scored offer — this drives the dashboard tally, "Last offer"
    // ticket, and History. Real data only: demo pills never pass through here.
    final candidate = OfferSummary(
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
      deliveryCount: offer.deliveryCount,
      itemCount: offer.itemCount,
      unitCount: offer.unitCount,
      scoringSnapshot: ScoringSnapshot.fromSettings(
        settings,
        platform: offer.rulesPlatform,
      ),
    );
    final summary = ref
        .read(offerLogProvider.notifier)
        .record(candidate, confirmedNewCard: _confirmedCardLeft);
    // record() returns the existing row for a duplicate. Announce only when
    // this exact candidate was inserted, never for card flicker/re-parses.
    final pillShown = ref
        .read(overlayControllerProvider.notifier)
        .showFromOffer(offer, verdict);
    if (identical(summary, candidate) &&
        settings.voiceVerdictEnabled &&
        (((settings.announceGoodOffers && verdict == Verdict.good) ||
                (settings.announceOkOffers && verdict == Verdict.ok)) &&
            ref
                .read(decisionEngineProvider)
                .qualifiesForVoice(offer, settings, verdict))) {
      _queueVoice(
        pillShown: pillShown,
        key: key,
        platform: offer.platform,
        verdict: verdict,
      );
    }
    _outcomeCandidates[offer.platform] = summary;
    _routeShadow.recordOffer(offer.platform, key, parsedTexts);
    if (!offer.isQueued && _activeTripScreens.contains(offer.platform)) {
      _offersShownDuringTrip[offer.platform] = summary;
    } else {
      _offersShownDuringTrip.remove(offer.platform);
    }
    _confirmedCardLeft = false;
  }

  void _scheduleOcrRetry(String packageName) {
    _pendingOcrPackage = packageName;
    if (_ocrRetryTimer != null) return;
    final elapsed = _lastOcrAt == null
        ? ocrCooldown
        : DateTime.now().difference(_lastOcrAt!);
    final delay = elapsed >= ocrCooldown
        ? Duration.zero
        : ocrCooldown - elapsed;
    _ocrRetryTimer = Timer(delay, () {
      _ocrRetryTimer = null;
      final pending = _pendingOcrPackage;
      _pendingOcrPackage = null;
      if (pending != null) unawaited(_requestOcr(pending, retryOnMiss: false));
    });
  }

  void _restoreCoveredRead() {
    final covered = _coveredRead;
    final seenAt = _coveredReadAt;
    _coveredRead = null;
    _coveredReadAt = null;
    if (covered == null ||
        seenAt == null ||
        DateTime.now().difference(seenAt) > coveredOfferFreshness) {
      return;
    }
    final parser = ref
        .read(parserRegistryProvider)
        .forPackage(covered.packageName);
    final offer = parser?.parse(covered.texts);
    if (offer == null || offer.platform == GigPlatform.uber) return;
    _suppressedKeys.remove(_keyFor(offer));
    _onRead(covered);
  }

  Future<void> _requestOcr(
    String packageName, {
    bool retryOnMiss = true,
  }) async {
    final settings = ref.read(settingsProvider);
    if (!settings.ocrEnabled ||
        !settings.watches(GigPlatform.uber) ||
        ref.read(dashboardProvider).status != WatchStatus.watching) {
      return;
    }
    final parser = ref.read(parserRegistryProvider).forPackage(packageName);
    if (parser == null || !settings.watches(parser.platform)) return;
    if (_ocrBusy) {
      if (retryOnMiss) _scheduleOcrRetry(packageName);
      return;
    }
    final now = DateTime.now();
    if (_lastOcrAt != null && now.difference(_lastOcrAt!) < ocrCooldown) {
      if (retryOnMiss) _scheduleOcrRetry(packageName);
      return;
    }
    _ocrRetryTimer?.cancel();
    _ocrRetryTimer = null;
    _pendingOcrPackage = null;
    _ocrBusy = true;
    _lastOcrAt = now;
    final accessibilityGeneration = _accessibilityOfferGeneration;
    var retry = false;
    try {
      final frame = await ref.read(ocrCaptureProvider).capture();
      if (!ref.mounted || frame.lines.isEmpty) {
        if (ref.mounted) {
          ref
              .read(foxLogProvider)
              .log(
                'ocr',
                'capture empty trigger=$packageName '
                    'active=${frame.packageName.isEmpty ? 'unknown' : frame.packageName} '
                    'ms=${DateTime.now().difference(now).inMilliseconds}',
              );
        }
        retry = retryOnMiss;
        return;
      }
      final activeParser = ref
          .read(parserRegistryProvider)
          .forPackage(frame.packageName);
      if (frame.packageName.isNotEmpty &&
          (activeParser == null ||
              !ref.read(settingsProvider).watches(activeParser.platform))) {
        ref
            .read(foxLogProvider)
            .log(
              'ocr',
              'discarded result outside selected driver app '
                  'active=${frame.packageName}',
            );
        return;
      }
      if (accessibilityGeneration != _accessibilityOfferGeneration) {
        ref
            .read(foxLogProvider)
            .log(
              'ocr',
              'discarded stale result trigger=$packageName '
                  'active=${frame.packageName.isEmpty ? 'unknown' : frame.packageName}',
            );
        retry = retryOnMiss;
        return;
      }
      ref
          .read(foxLogProvider)
          .log(
            'ocr',
            'recognized ${frame.lines.length} lines '
                'trigger=$packageName '
                'active=${frame.packageName.isEmpty ? 'unknown' : frame.packageName} '
                'ms=${DateTime.now().difference(now).inMilliseconds}',
          );
      _onRead(
        ScreenRead(
          packageName: frame.packageName.isEmpty
              ? packageName
              : frame.packageName,
          texts: frame.lines,
          isActive: true,
          source: CaptureSource.ocr,
        ),
      );
      retry = retryOnMiss && !_ocrMatched;
    } catch (_) {
      if (ref.mounted) {
        ref.read(foxLogProvider).log('ocr', 'capture failed');
      }
      retry = retryOnMiss;
    } finally {
      _ocrBusy = false;
      if (retry && ref.mounted) _scheduleOcrRetry(packageName);
    }
  }

  /// Stamp taken/missed onto [platform]'s last exact logged candidate from
  /// whatever that app is showing NOW — regardless of whether its pill is up.
  ///
  /// The pill is short-lived by design (5 s floor, 7 s [idleTimeout] once the
  /// app goes quiet), but accepting is slow: the driver taps Accept inside the
  /// gig app, switches to it, and sets up navigation. The in-trip screen that
  /// proves the accept therefore usually arrives long after the pill died, and
  /// with `_shownKey` already null every later frame used to be dropped as
  /// browse noise — so real accepted Uber and Lyft trips logged as not taken
  /// (device 2026-08-06). Outcome must outlive the pill.
  ///
  /// The exact candidate stored when the card was logged owns the result, so
  /// repeated trip-screen frames cannot mark older same-platform offers too.
  void _inferOutcome(
    GigPlatform platform,
    List<String> texts, {
    required bool isActive,
  }) {
    if (!isActive) return;
    final queuedAccepted = ParserPatterns.looksLikeQueuedOfferAccepted(
      platform,
      texts,
    );
    final accepted =
        queuedAccepted || ParserPatterns.looksLikeAcceptedTrip(platform, texts);
    if (accepted) _routeShadow.observeAcceptedScreen(platform, texts);
    if (!ref.read(settingsProvider).trackOutcomes) return;
    final candidate = _outcomeCandidates[platform];
    if (candidate == null) return;
    if (identical(_offersShownDuringTrip[platform], candidate) &&
        !queuedAccepted) {
      return;
    }
    if (accepted) {
      if (_pendingOutcomePlatform == platform) _cancelPendingOutcome();
      final changed = ref
          .read(offerLogProvider.notifier)
          .markOutcome(
            candidate,
            OfferOutcome.taken,
            includeQueued: queuedAccepted,
          );
      if (changed) {
        ref
            .read(foxLogProvider)
            .log('outcome', '${platform.label} offer inferred taken');
      }
      return;
    }
    // Card hallmarks mean the offer is still on screen — a half-rendered frame,
    // not a decision. Cancel anything armed from the previous frame.
    if (ParserPatterns.looksLikeOfferCard(
      texts,
      onBrowse: ParserPatterns.looksLikeBrowse(texts.join(' ')),
    )) {
      if (_pendingOutcomePlatform == platform) _cancelPendingOutcome();
      return;
    }
    final outcome = ParserPatterns.looksLikeBrowse(texts.join(' '))
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
    final candidate = platform == null ? null : _outcomeCandidates[platform];
    _cancelPendingOutcome();
    if (platform == null ||
        candidate == null ||
        outcome == OfferOutcome.unknown) {
      return;
    }
    final changed = ref
        .read(offerLogProvider.notifier)
        .markOutcome(candidate, outcome);
    if (changed) {
      ref
          .read(foxLogProvider)
          .log('outcome', '${platform.label} offer inferred ${outcome.name}');
    }
  }

  void _logCardMiss(
    OfferParser parser,
    List<String> texts, {
    required CaptureSource source,
  }) {
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
              'nodes=${texts.length} source=${source.name}$repeated',
        );
  }

  /// The offer stayed gone for the whole grace window — really clear now.
  /// Forget what we showed (so the same offer reappearing shows again) and drop
  /// the pill back to the bubble. Outcome is NOT stamped here: it now runs on
  /// its own clock in [_inferOutcome], because the screen that proves the
  /// accept usually arrives well after the pill is gone.
  void _clearNow({String reason = 'offer left screen'}) {
    _clearTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_shownKey == null) return;
    _cancelPendingVoice('offer cleared');
    _suppressedKeys.add(_shownKey!);
    _shownKey = null;
    _shownPlatform = null;
    _shownWindowId = null;
    state = null;
    ref.read(overlayControllerProvider.notifier).clearOffer();
    ref.read(foxLogProvider).log('overlay', 'pill cleared — $reason');
    if (kDebugMode) debugPrint('FoxyCo[watch] clear: $reason');
  }
}

final offerWatcherProvider = NotifierProvider<OfferWatcher, Offer?>(
  OfferWatcher.new,
);
