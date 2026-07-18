import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'dashboard_state.dart';

/// Slide-to-go-live control (spec M6 §3.2).
///
/// Replaces the hero's tap `_ActiveButton` with a full-width slide gesture so
/// going live / stopping is a deliberate, hard-to-mistake action:
///  - Stopped/blocked → drag the thumb right; commit at ≥85% travel → onStart.
///  - Watching/paused → drag the thumb back (right→left) to ≥85% → onStop.
///  - Blocked → the track routes taps to onFix (grant access).
///
/// A parallel [Semantics] button exposes tap-activation for screen readers and
/// reduced-motion users, wired to the same callbacks (no sliding required).
class SlideToLive extends StatefulWidget {
  const SlideToLive({
    super.key,
    required this.status,
    required this.onStart,
    required this.onStop,
    required this.onFix,
  });

  final WatchStatus status;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onFix;

  /// Travel fraction (0..1) the thumb must reach to commit the action.
  static const commitFraction = 0.85;

  @override
  State<SlideToLive> createState() => _SlideToLiveState();
}

class _SlideToLiveState extends State<SlideToLive>
    with SingleTickerProviderStateMixin {
  double _drag = 0; // 0..1 travel fraction while dragging
  bool _dragging = false;
  bool _reduced = false; // mirrors MediaQuery.disableAnimations
  late final AnimationController _spring;

  static const _height = 56.0;
  static const _thumb = 44.0;

  bool get _running =>
      widget.status == WatchStatus.watching ||
      widget.status == WatchStatus.paused;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(vsync: this, duration: Motion.morph);
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _release(double travel) {
    if (travel >= SlideToLive.commitFraction) {
      HapticFeedback.mediumImpact();
      setState(() {
        _drag = 0;
        _dragging = false;
      });
      _running ? widget.onStop() : widget.onStart();
    } else {
      HapticFeedback.lightImpact();
      // Reduced motion: snap back with no spring loop.
      if (_reduced) {
        setState(() {
          _drag = 0;
          _dragging = false;
        });
        return;
      }
      // Spring back with overshoot (user-driven gesture → spring allowed).
      final from = _drag;
      final tick = _onSpringTick(from);
      _spring
        ..reset()
        ..addListener(tick)
        ..forward().whenComplete(() {
          _spring.removeListener(tick);
          if (mounted) setState(() => _dragging = false);
        });
    }
  }

  VoidCallback _onSpringTick(double from) => () {
        final t = Motion.spring.transform(_spring.value);
        if (mounted) setState(() => _drag = from * (1 - t));
      };

  @override
  Widget build(BuildContext context) {
    _reduced = MediaQuery.of(context).disableAnimations;
    final blocked = widget.status == WatchStatus.blocked;

    final label = blocked
        ? 'Grant access'
        : _running
            ? 'Stop'
            : 'Go live';

    return Semantics(
      key: const ValueKey('slide-to-live-semantics'),
      button: true,
      label: label,
      onTap: blocked
          ? widget.onFix
          : _running
              ? widget.onStop
              : widget.onStart,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: _reduced ? Duration.zero : Motion.morph,
          switchInCurve: Motion.curve,
          switchOutCurve: Motion.curve,
          child: _running ? _liveBar(context) : _slideTrack(context),
        ),
      ),
    );
  }

  /// Stopped/blocked: slide-right-to-go-live track.
  Widget _slideTrack(BuildContext context) {
    final blocked = widget.status == WatchStatus.blocked;
    return LayoutBuilder(
      key: const ValueKey('track'),
      builder: (context, c) {
        final travelPx = c.maxWidth - _thumb - 12;
        final x = _drag * travelPx;
        return GestureDetector(
          onTap: blocked ? widget.onFix : null,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: FoxColors.bgSurface2,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: FoxColors.border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Orange fill rising behind the thumb.
                AnimatedContainer(
                  duration: (_dragging || _reduced) ? Duration.zero : Motion.fast,
                  width: x + _thumb + 6,
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    gradient: LinearGradient(
                      colors: [
                        FoxColors.brandFoxDeep
                            .withValues(alpha: 0.0 + 0.6 * _drag),
                        FoxColors.brandFox.withValues(alpha: 0.15 + 0.7 * _drag),
                      ],
                    ),
                  ),
                ),
                // Label fades as the fill passes it.
                Center(
                  child: Opacity(
                    opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                    child: Text(
                      blocked ? 'Grant access to go live' : 'Slide to go live',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: 6 + x,
                  child: GestureDetector(
                    key: const ValueKey('slide-thumb'),
                    onHorizontalDragStart:
                        blocked ? null : (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: blocked
                        ? null
                        : (d) => setState(() => _drag =
                            (_drag + d.delta.dx / travelPx).clamp(0.0, 1.0)),
                    onHorizontalDragEnd:
                        blocked ? null : (_) => _release(_drag),
                    onHorizontalDragCancel:
                        blocked ? null : () => _release(_drag),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color:
                            blocked ? FoxColors.textDisabled : FoxColors.brandFox,
                        shape: BoxShape.circle,
                        boxShadow: _reduced ? null : Shadows.glow,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Watching/paused: slide-back-to-stop bar.
  Widget _liveBar(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('live'),
      builder: (context, c) {
        final travelPx = c.maxWidth - _thumb - 12;
        // Stop-drag is RIGHT→LEFT: thumb starts on the left (x = 0) and the
        // driver drags it back; _drag tracks 0..1 travel.
        final x = _drag * travelPx;
        final paused = widget.status == WatchStatus.paused;
        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: FoxColors.brandFox.withValues(alpha: 0.4),
            ),
            boxShadow: _reduced ? null : Shadows.glowSoft,
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Gap.md + Gap.xs),
                child: Row(
                  children: [
                    _PulsingDot(reduced: _reduced || paused),
                    const SizedBox(width: Gap.sm),
                    Text(
                      paused ? 'Paused' : 'Live',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.cream,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Opacity(
                        opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                        child: const Text(
                          '· slide back to stop',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FoxColors.textDisabled,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 6 + x,
                child: GestureDetector(
                  key: const ValueKey('slide-stop-thumb'),
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) => setState(() => _drag =
                      (_drag - d.delta.dx / travelPx).clamp(0.0, 1.0)),
                  onHorizontalDragEnd: (_) => _release(_drag),
                  onHorizontalDragCancel: () => _release(_drag),
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: FoxColors.brandFox,
                      shape: BoxShape.circle,
                      boxShadow: _reduced ? null : Shadows.glowSoft,
                    ),
                    child: const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pulsing live dot; steady (no loop) under reduced motion / paused.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.reduced});
  final bool reduced;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.reduced && _c.isAnimating) _c.stop();
    if (!widget.reduced && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: FoxColors.brandFox,
          shape: BoxShape.circle,
          boxShadow: widget.reduced
              ? null
              : [
                  BoxShadow(
                    color: FoxColors.brandFox
                        .withValues(alpha: 0.3 + 0.4 * _c.value),
                    blurRadius: 6 + 8 * _c.value,
                  ),
                ],
        ),
      ),
    );
  }
}
