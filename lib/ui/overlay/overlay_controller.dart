import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer.dart';
import '../../domain/overlay_action.dart';
import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../../services/billing/entitlement.dart';
import '../../services/fox_log.dart';
import '../../services/offer_log.dart';
import '../../services/overlay_service.dart';
import '../paywall/paywall_sheet.dart';
import '../home/dashboard_controller.dart';
import '../home/dashboard_state.dart';
import '../settings/settings_controller.dart';
import '../shell/root_shell.dart';

/// DI seam for the overlay plugin wrapper, so widgets/tests depend on the
/// interface, not the plugin. Overridden in tests with a fake.
final overlayServiceProvider = Provider<OverlayService>(
  (ref) => const OverlayService(),
);

/// Drives the overlay from the main isolate. Two responsibilities:
///
///   1. **Overlay lifecycle follows watch status** (HANDOFF req 11). The bubble
///      is NOT a debug artifact — it appears the moment the dashboard is
///      `watching`, dims when `paused`, and tears down when `blocked`/stopped.
///      Before, the overlay only ever came up via the "Simulate offer" button.
///   2. **Bubble gestures route back into the app** via [OverlayService.actionStream]:
///      tap → foreground FoxyCo, long-press → pause/resume, drop-to-bottom →
///      stop watching. Each is echoed into dashboard state so the bubble and the
///      dashboard never disagree.
class OverlayController extends Notifier<void> {
  StreamSubscription<OverlayAction>? _actionSub;

  /// Overlay start/hide calls cross a platform channel and can finish out of
  /// order. Serialize status transitions so a slow "start" can never complete
  /// after a later "stop" and leave a ghost bubble/mask onscreen.
  Future<void> _statusWork = Future<void>.value();

  /// True while a REAL offer pill is on the bubble (demo pills excluded — they
  /// never reach the offer log, so there'd be nothing to open). Decides whether
  /// a bubble tap deep-links to that offer or just foregrounds the app.
  bool _pillUp = false;

  @override
  void build() {
    _actionSub = _service.actionStream.listen(_onAction);
    ref.onDispose(() => _actionSub?.cancel());

    // Mirror every watch-status change onto the overlay window. `fireImmediately`
    // applies the CURRENT status too, so first-boot `watching` brings the bubble
    // up without waiting for a change (fixes "bubble only via Simulate", req 11).
    ref.listen<WatchStatus>(
      dashboardProvider.select((s) => s.status),
      (_, next) => _queueStatus(next),
      fireImmediately: true,
    );
  }

  OverlayService get _service => ref.read(overlayServiceProvider);

  void _queueStatus(WatchStatus status) {
    _statusWork = _statusWork.then((_) => _applyStatus(status)).catchError((
      Object error,
      StackTrace stack,
    ) {
      ref.read(foxLogProvider).log('error', 'overlay lifecycle: $error');
    });
  }

  /// Bring the overlay up / dim / tear it down to match [status]. Idempotent and
  /// safe to call when the window is already in the target state (the plugin
  /// calls no-op). Async but fire-and-forget from the listener.
  Future<void> _applyStatus(WatchStatus status) async {
    switch (status) {
      case WatchStatus.watching:
        // Online: bring the bubble up.
        await _service.startWatching(paused: false);
      case WatchStatus.paused:
      case WatchStatus.blocked:
      case WatchStatus.stopped:
        // Off in any flavor: tear the overlay down completely — no lingering
        // bubble. Going online again re-creates it. (Driver asked for a clean
        // on/off, not a dimmed bubble that sits there.)
        await hide();
    }
  }

  /// Handle a gesture that originated on the overlay bubble.
  void _onAction(OverlayAction action) {
    switch (action) {
      case OverlayAction.togglePause:
        // Long-press the bubble to go offline. togglePause() flips the
        // dashboard status; the status listener tears the overlay down (offline
        // == no bubble), so there's nothing else to do here.
        ref.read(dashboardProvider.notifier).togglePause();
      case OverlayAction.openApp:
        // Tapping the bubble brings FoxyCo forward — Android reroutes to the
        // launcher activity via the plugin's tap intent. If a pill is up the
        // driver is asking about THAT offer, so land on it instead of dumping
        // them on Home to go hunt for it. The pill's offer is always the newest
        // log entry: OfferWatcher records it immediately before showing it.
        final log = ref.read(offerLogProvider);
        if (!_pillUp || log.isEmpty) break;
        ref.read(tabIndexProvider.notifier).go(1);
        ref.read(pendingOfferProvider.notifier).set(log.first);
      case OverlayAction.openPaywall:
        // Locked pill tapped: the driver just tried to read a verdict they
        // haven't paid for. Land them on Home with the paywall sheet up — the
        // overlay already brought the app forward.
        ref.read(tabIndexProvider.notifier).go(0);
        ref.read(paywallRequestProvider.notifier).request();
      case OverlayAction.stopWatching:
        // Bubble dragged into the bottom drop zone. Native already closed the
        // window; flip the dashboard so it doesn't keep showing "Watching"
        // (req 10). stopWatching() → paused, which our status listener maps to
        // setPaused (a no-op on the now-closed window).
        ref.read(dashboardProvider.notifier).stopWatching();
    }
  }

  /// Show a real scored offer on the overlay pill. The single entry point for
  /// the M3 pipeline (accessibility → parser → engine → here). Maps the parsed
  /// [Offer] to the tiny cross-isolate [OverlayPayload], carrying totalMinutes
  /// ($/hr), the pickup split + the driver's near-pickup cutoff (km coloring),
  /// and the driver's chosen pill size.
  Future<void> showFromOffer(Offer offer, Verdict verdict) async {
    // A read already in flight may finish just after the driver stops. Never
    // let that stale result recreate the overlay window.
    if (ref.read(dashboardProvider).status != WatchStatus.watching) return;
    _pillUp = true;
    final settings = ref.read(settingsProvider);
    // Patch site 1 of 2 (MONETIZATION §4): the payload carries entitlement, the
    // overlay isolate independently refuses to draw numbers without it. Read
    // fresh per offer — a trial that lapsed mid-shift locks the next pill.
    final entitled = ref.read(entitledProvider);
    ref
        .read(foxLogProvider)
        .log(
          'overlay',
          'show ${offer.platform.label} \$${offer.payout} $verdict',
        );
    await _service.showOffer(
      OverlayPayload(
        verdict: verdict,
        totalKm: offer.totalKm,
        payout: offer.payout,
        totalMinutes: offer.totalMinutes,
        pickupKm: offer.pickupKm,
        pickupNearKm: settings.pickupNearKm,
        hourGoodAt: settings.hourThresholds.goodAtOrAbove,
        hourBadBelow: settings.hourThresholds.badBelow,
        size: settings.pillSize,
        moneyFont: settings.moneyFont,
        entitled: entitled,
      ),
    );
    // Stop/pause may have landed while native showOverlay was starting. Clean
    // up immediately; the serialized status queue will also converge on hide.
    if (ref.read(dashboardProvider).status != WatchStatus.watching) {
      _pillUp = false;
      await _service.hide();
    }
  }

  /// Clear the pill the instant the offer leaves the screen (HANDOFF reqs 6–7):
  /// pill visibility tracks "offer present", not a timer. The overlay window
  /// stays up in its bubble state — only the pill content drops. The pipeline
  /// calls this when a watched app is foregrounded but the screen no longer
  /// parses as an offer, so a stale verdict never sits over a browse map.
  Future<void> clearOffer() {
    _pillUp = false;
    return _service.clearPill();
  }

  /// A rotating set of fake offers so repeated taps show different verdicts.
  /// Minutes included so the debug flow exercises the $/hr line too.
  static const _samples = <OverlayPayload>[
    OverlayPayload(
      verdict: Verdict.good,
      totalKm: 8.4,
      payout: 12,
      totalMinutes: 24,
      hourGoodAt: 30,
      hourBadBelow: 20,
      // The demo pill is free forever (MONETIZATION §4) — it is the thing that
      // shows a locked driver what they'd be buying.
      entitled: true,
    ),
    OverlayPayload(
      verdict: Verdict.ok,
      totalKm: 6.2,
      payout: 7.5,
      totalMinutes: 21,
      hourGoodAt: 30,
      hourBadBelow: 20,
      // The demo pill is free forever (MONETIZATION §4) — it is the thing that
      // shows a locked driver what they'd be buying.
      entitled: true,
    ),
    OverlayPayload(
      verdict: Verdict.bad,
      totalKm: 11.0,
      payout: 6,
      totalMinutes: 33,
      hourGoodAt: 30,
      hourBadBelow: 20,
      // The demo pill is free forever (MONETIZATION §4) — it is the thing that
      // shows a locked driver what they'd be buying.
      entitled: true,
    ),
  ];
  int _next = 0;

  /// True if a pill was shown; false if we had to send the user to settings to
  /// grant "Display over other apps" first.
  Future<bool> simulateOffer() async {
    if (!await _service.isPermissionGranted()) {
      final granted = await _service.requestPermission();
      if (!granted) return false;
    }
    final sample = _samples[_next % _samples.length];
    _next++;
    await _service.showOffer(sample);
    // Demo only: no real offer will "leave the screen" to clear this, so
    // auto-retract after a few seconds instead of leaving the pill stuck.
    // (A real pill is cleared either by the card leaving or by
    // OfferWatcher.idleTimeout; neither fires for a demo.) And because showOffer
    // had to bring the
    // overlay WINDOW up to draw the pill, an offline demo must tear the
    // whole window down again — otherwise a "watching" bubble lingers while
    // the dashboard says stopped (device 2026-07-18). Online, only the pill
    // drops and the real bubble stays.
    Timer(const Duration(seconds: 5), () async {
      final status = ref.read(dashboardProvider).status;
      if (status == WatchStatus.watching || status == WatchStatus.paused) {
        await _service.clearPill();
      } else {
        await _service.hide();
      }
    });
    return true;
  }

  Future<void> hide() {
    _pillUp = false;
    return _service.hide();
  }
}

final overlayControllerProvider = NotifierProvider<OverlayController, void>(
  OverlayController.new,
);
