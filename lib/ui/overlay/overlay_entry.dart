import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../domain/overlay_action.dart';
import '../../domain/overlay_control.dart';
import '../../domain/overlay_payload.dart';
import '../theme/tokens.dart';
import 'fox_bubble.dart';
import 'verdict_pill.dart';

/// TEMP diagnostic. When true the overlay paints a translucent tint across the
/// whole window so its presence is unmistakable on device. OFF now — visibility
/// is confirmed; with the compact window this would only tint the small box.
const bool _kOverlayDebug = false;

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
      home: Scaffold(backgroundColor: Colors.transparent, body: _OverlayRoot()),
    );
  }
}

class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot();

  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  /// Safety fallback only. The pill's real lifecycle is now driven by the main
  /// isolate: it shows on an `offer` message and clears on a `clearPill` control
  /// message the instant the offer leaves the screen (HANDOFF reqs 6–7). This
  /// timer just guards against a missed clear (app killed mid-offer, dropped
  /// message) so a pill can't linger forever — deliberately long so it never
  /// pre-empts a still-present offer the way the old 12 s timer did.
  static const _dismissAfter = Duration(seconds: 45);

  /// Window sizes in **dp** (resizeOverlay converts to px). The window is grown
  /// to fit the pill while an offer shows, then shrunk back to the bubble so it
  /// hugs an edge and drags freely. Keep these in sync with the widgets: pill
  /// width must hold the widest verdict line, bubble = FoxBubble.size + margin.
  //
  // The pill window MUST stay narrower than the screen, or it can't be dragged:
  // the native X-clamp is `maxX = screenWidth - windowWidth`, so a 360dp window
  // on the S24's 360dp-wide screen pins maxX to 0 and the (centered) pill is
  // stuck mid-screen — exactly the "lands in centre, won't go to an edge" bug.
  // 300dp holds the compact `small` pill (verdict WORD + "$7 · $1.21/km · $73/hr")
  // and leaves real horizontal travel so it can snap to either edge.
  //
  // Per-size boxes (spec M5 §1). Width MUST stay <360dp — see comment above.
  static ({int w, int h}) _pillBoxFor(PillSize size) => switch (size) {
        PillSize.small => (w: 300, h: 72),
        PillSize.medium => (w: 324, h: 84),
        PillSize.large => (w: 348, h: 100),
      };
  static const _bubbleBox = (w: 72, h: 72);

  OverlayPayload? _payload;
  bool _paused = false;
  StreamSubscription<dynamic>? _sub;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('FoxyCo[overlay] _OverlayRoot.initState — attaching listener');
    }
    _sub = FlutterOverlayWindow.overlayListener.listen(_onData);
  }

  /// Grow/shrink the overlay window to match the current content. Called from
  /// the overlay isolate (where resizeOverlay's method channel is registered).
  /// The pill stretch is centered on screen (centerX) — reading a verdict
  /// pinned to whichever edge the bubble was hugging was awkward; native
  /// restores the bubble's edge X on the shrink back.
  void _resize(({int w, int h}) box, {bool centerX = false}) =>
      FlutterOverlayWindow.resizeOverlay(box.w, box.h, true, centerX: centerX);

  /// Route an inbound `shareData` map by its `kind` tag. Anything unrecognized
  /// is ignored (fail safe) so a stray message never crashes the overlay.
  void _onData(dynamic data) {
    if (kDebugMode) debugPrint('FoxyCo[overlay] _onData: $data');
    if (data is! Map) return;

    if (OverlayControl.isControl(data)) {
      if (data['paused'] is bool) setState(() => _paused = data['paused']);
      if (data['clearPill'] == true) _clearPill();
      return;
    }

    if (data['kind'] == 'offer') {
      final payload = OverlayPayload.fromMap(data);
      setState(() => _payload = payload);
      _resize(_pillBoxFor(payload.size), centerX: true); // centered pill
      _dismissTimer?.cancel();
      _dismissTimer = Timer(_dismissAfter, _clearPill);
    }
  }

  void _clearPill() {
    if (!mounted) return;
    if (_payload == null) {
      // Already a bubble (e.g. clearPill's belt-and-braces second send) —
      // just make sure the window is bubble-sized.
      _resize(_bubbleBox);
      return;
    }
    setState(() => _payload = null);
    // Let the pill→bubble cross-fade play out inside the still-large window
    // BEFORE shrinking it. Resizing in the same frame clipped the pill
    // mid-fade — the retract read as a hard snap (device 2026-07-19). If a
    // new offer lands during the fade, _onData re-grows the window and the
    // payload check below skips the stale shrink.
    Timer(Motion.base + const Duration(milliseconds: 40), () {
      if (mounted && _payload == null) _resize(_bubbleBox);
    });
  }

  // Bubble gestures → actions sent back to the main isolate.
  // Tap foregrounds FoxyCo. We call bringHostToFront() DIRECTLY on the overlay
  // method channel (reliable — same path as resizeOverlay) rather than routing
  // an openApp action through the messenger, which looped back here and never
  // reached native. Still emit the action too, for the main isolate's hooks.
  void _onBubbleTap() {
    FlutterOverlayWindow.bringHostToFront();
    FlutterOverlayWindow.shareData(OverlayAction.openApp.toMap());
  }

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
    // (build-time debugPrint removed — it fired on every frame of the
    // AnimatedSwitcher cross-fade + plasma ring, spamming logcat all session.)
    // The overlay window is a COMPACT box resting on the right edge (see
    // OverlayService) — small on purpose so it only captures touches over
    // itself, never the whole screen. Center our single widget in it: the
    // verdict pill while an offer is live, otherwise the resting bubble. The
    // main isolate drives the pill's life — it clears the instant the offer
    // card leaves the screen; the 45s timer here is only a dropped-message net.
    final content = Center(
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
            ? FoxBubble(
                key: const ValueKey('bubble'),
                paused: _paused,
                onTap: _onBubbleTap,
                onLongPress: _onBubbleLongPress,
              )
            : GestureDetector(
                // Absorb taps on the pill so a stray touch can't dismiss it —
                // the driver needs it to STAY put while they read the offer.
                // The pill's life is driven entirely by the main isolate: it
                // clears the instant the offer card leaves the screen (accept /
                // decline / dismiss), never on a tap. onTap is a no-op that just
                // swallows the gesture (opaque hit-test below).
                key: ValueKey('pill-${payload.hashCode}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: VerdictPill(payload: payload),
              ),
      ),
    );

    if (!_kOverlayDebug) return content;
    // Diagnostic: translucent full-screen tint proves the window rendered.
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0x33FF00FF))),
        content,
      ],
    );
  }
}
