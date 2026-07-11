import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/overlay_action.dart';
import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../../services/overlay_service.dart';
import '../home/dashboard_controller.dart';
import '../home/dashboard_state.dart';

/// DI seam for the overlay plugin wrapper, so widgets/tests depend on the
/// interface, not the plugin. Overridden in tests with a fake.
final overlayServiceProvider =
    Provider<OverlayService>((ref) => const OverlayService());

/// Drives the overlay from the main isolate: the "simulate offer" debug flow
/// (M2 done-when check) plus routing the bubble's gestures back into the app.
///
/// Listens to [OverlayService.actionStream] so a bubble tap opens FoxyCo and a
/// long-press pauses/resumes watching — the pause is echoed back to the overlay
/// so the bubble's dimmed state always matches the real engine state.
class OverlayController extends Notifier<void> {
  StreamSubscription<OverlayAction>? _actionSub;

  @override
  void build() {
    _actionSub = _service.actionStream.listen(_onAction);
    ref.onDispose(() => _actionSub?.cancel());
  }

  OverlayService get _service => ref.read(overlayServiceProvider);

  /// Handle a gesture that originated on the overlay bubble.
  void _onAction(OverlayAction action) {
    switch (action) {
      case OverlayAction.togglePause:
        ref.read(dashboardProvider.notifier).togglePause();
        final paused =
            ref.read(dashboardProvider).status == WatchStatus.paused;
        _service.setPaused(paused); // keep the bubble's dim state truthful
      case OverlayAction.openApp:
        // Tapping the bubble brings FoxyCo forward. Android reroutes to the
        // launcher activity via the plugin's tap intent; nothing to do here
        // yet beyond leaving the hook in place for deep-linking later.
        break;
    }
  }

  /// A rotating set of fake offers so repeated taps show different verdicts.
  static const _samples = <OverlayPayload>[
    OverlayPayload(verdict: Verdict.good, totalKm: 8.4, payout: 12),
    OverlayPayload(verdict: Verdict.ok, totalKm: 6.2, payout: 7.5),
    OverlayPayload(verdict: Verdict.bad, totalKm: 11.0, payout: 6),
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
    return true;
  }

  Future<void> hide() => _service.hide();
}

final overlayControllerProvider =
    NotifierProvider<OverlayController, void>(OverlayController.new);
