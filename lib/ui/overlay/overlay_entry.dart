import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../domain/overlay_action.dart';
import '../../domain/overlay_control.dart';
import '../../domain/overlay_payload.dart';
import '../theme/tokens.dart';
import 'fox_bubble.dart';
import 'verdict_pill.dart';

/// The overlay ISOLATE's UI (docs/OVERLAY §separate isolate).
///
/// `flutter_overlay_window` boots this via a second `runApp` in its own isolate
/// (from `overlayMain` in main.dart) with no shared memory — it can't see
/// Riverpod or anything on the main side. Messages cross via `shareData`:
///   • main → overlay: [OverlayPayload] (an offer) or [OverlayControl] (paused / clear)
///   • overlay → main: [OverlayAction] (bubble tap / long-press)
///
/// Layout: the resting [FoxBubble] always sits at an edge; a [VerdictPill]
/// drops in at the top when an offer arrives and auto-clears after a timeout.
class FoxOverlayApp extends StatelessWidget {
  const FoxOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // Transparent so only our widgets paint; the app underneath shows through.
      color: Colors.transparent,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _OverlayRoot(),
      ),
    );
  }
}

class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot();

  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  /// How long a pill lingers before it fades out on its own. The overlay window
  /// stays alive (bubble-ready); only the pill content clears.
  static const _dismissAfter = Duration(seconds: 12);

  OverlayPayload? _payload;
  bool _paused = false;
  StreamSubscription<dynamic>? _sub;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen(_onData);
  }

  /// Route an inbound `shareData` map by its `kind` tag. Anything unrecognized
  /// is ignored (fail safe) so a stray message never crashes the overlay.
  void _onData(dynamic data) {
    if (data is! Map) return;

    if (OverlayControl.isControl(data)) {
      if (data['paused'] is bool) setState(() => _paused = data['paused']);
      if (data['clearPill'] == true) _clearPill();
      return;
    }

    if (data['kind'] == 'offer') {
      setState(() => _payload = OverlayPayload.fromMap(data));
      _dismissTimer?.cancel();
      _dismissTimer = Timer(_dismissAfter, _clearPill);
    }
  }

  void _clearPill() {
    if (mounted) setState(() => _payload = null);
  }

  // Bubble gestures → actions sent back to the main isolate.
  void _onBubbleTap() => FlutterOverlayWindow.shareData(OverlayAction.openApp.toMap());

  void _onBubbleLongPress() {
    // Optimistically flip locally so it feels instant; main echoes the truth
    // back via an OverlayControl.paused message.
    setState(() => _paused = !_paused);
    FlutterOverlayWindow.shareData(OverlayAction.togglePause.toMap());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    return SafeArea(
      child: Stack(
        children: [
          // Verdict pill — drops in at top-center on an offer.
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.curve,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: payload == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(payload.hashCode),
                      padding: const EdgeInsets.only(top: Gap.sm),
                      child: VerdictPill(payload: payload),
                    ),
            ),
          ),

          // Resting bubble — always present, pinned bottom-right by default.
          // (The plugin's window drag repositions the whole overlay; snap is
          // handled by positionGravity in OverlayService.)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: FoxBubble(
                paused: _paused,
                onTap: _onBubbleTap,
                onLongPress: _onBubbleLongPress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
