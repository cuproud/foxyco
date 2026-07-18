import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer.dart';
import '../../domain/overlay_action.dart';
import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../../services/fox_log.dart';
import '../../services/overlay_service.dart';
import '../home/dashboard_controller.dart';
import '../home/dashboard_state.dart';
import '../settings/settings_controller.dart';

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

  @override
  void build() {
    _actionSub = _service.actionStream.listen(_onAction);
    ref.onDispose(() => _actionSub?.cancel());

    // Mirror every watch-status change onto the overlay window. `fireImmediately`
    // applies the CURRENT status too, so first-boot `watching` brings the bubble
    // up without waiting for a change (fixes "bubble only via Simulate", req 11).
    ref.listen<WatchStatus>(
      dashboardProvider.select((s) => s.status),
      (_, next) => _applyStatus(next),
      fireImmediately: true,
    );
  }

  OverlayService get _service => ref.read(overlayServiceProvider);

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
        await _service.hide();
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
        // Tapping the bubble brings FoxyCo forward. Android reroutes to the
        // launcher activity via the plugin's tap intent; nothing to do here
        // yet beyond leaving the hook in place for deep-linking later.
        break;
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
  Future<void> showFromOffer(Offer offer, Verdict verdict) {
    final settings = ref.read(settingsProvider);
    ref
        .read(foxLogProvider)
        .log('overlay', 'show ${offer.platform.label} \$${offer.payout} $verdict');
    return _service.showOffer(
      OverlayPayload(
        verdict: verdict,
        totalKm: offer.totalKm,
        payout: offer.payout,
        totalMinutes: offer.totalMinutes,
        pickupKm: offer.pickupKm,
        pickupNearKm: settings.pickupNearKm,
        size: settings.pillSize,
      ),
    );
  }

  /// Clear the pill the instant the offer leaves the screen (HANDOFF reqs 6–7):
  /// pill visibility tracks "offer present", not a timer. The overlay window
  /// stays up in its bubble state — only the pill content drops. The pipeline
  /// calls this when a watched app is foregrounded but the screen no longer
  /// parses as an offer, so a stale verdict never sits over a browse map.
  Future<void> clearOffer() => _service.clearPill();

  /// A rotating set of fake offers so repeated taps show different verdicts.
  /// Minutes included so the debug flow exercises the $/hr line too.
  static const _samples = <OverlayPayload>[
    OverlayPayload(verdict: Verdict.good, totalKm: 8.4, payout: 12, totalMinutes: 24),
    OverlayPayload(verdict: Verdict.ok, totalKm: 6.2, payout: 7.5, totalMinutes: 21),
    OverlayPayload(verdict: Verdict.bad, totalKm: 11.0, payout: 6, totalMinutes: 33),
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
    // auto-retract to the resting bubble after a few seconds instead of
    // leaving the pill stuck until the 45 s safety timer.
    Timer(const Duration(seconds: 5), _service.clearPill);
    return true;
  }

  Future<void> hide() => _service.hide();
}

final overlayControllerProvider = NotifierProvider<OverlayController, void>(
  OverlayController.new,
);
