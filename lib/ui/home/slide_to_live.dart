import 'dart:math' as math;

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
  static const _stopHint = '· slide back to stop';

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
        final label = blocked ? 'Grant access to go live' : 'Slide to go live';
        final labelStyle = TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          // On-card token: textSecondary is the PAGE's, and it washed out
          // against the track (device 2026-07-25).
          color: FoxColors.creamDim,
        );
        final labelW = _textWidth(context, label, labelStyle);
        return GestureDetector(
          onTap: blocked ? widget.onFix : null,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              // A well cut into the CARD, so it stays recessed whichever way
              // the theme goes — the page tokens (bgSurface2/border) read as a
              // pale slab sitting on top of the card instead (device
              // 2026-07-25: "washed out").
              color: FoxColors.cream.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: FoxColors.cream.withValues(alpha: 0.18),
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Orange fill rising behind the thumb.
                AnimatedContainer(
                  duration: (_dragging || _reduced)
                      ? Duration.zero
                      : Motion.fast,
                  width: x + _thumb + 6,
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    gradient: LinearGradient(
                      colors: [
                        FoxColors.brandFoxDeep.withValues(
                          alpha: 0.0 + 0.6 * _drag,
                        ),
                        FoxColors.brandFox.withValues(
                          alpha: 0.15 + 0.7 * _drag,
                        ),
                      ],
                    ),
                  ),
                ),
                // Glass cue spanning the WHOLE track (design 2026-07-25 — the
                // old 60 px chevron band hid in the last inch of the card and
                // read as a detail, not an invitation). A cream sheen sweeps
                // the full width, with the chevron train marching across it.
                // Both sit UNDER the label and fade as the fill rises.
                if (!blocked) ...[
                  Positioned.fill(
                    child: _GlassSweep(
                      reduced: _reduced,
                      opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                    ),
                  ),
                  Positioned.fill(
                    child: _MarchingChevrons(
                      reduced: _reduced,
                      // 0.85, not 0.55: at 0.55 the train read as smudges and
                      // the "drag me" cue didn't land (device 2026-07-25).
                      opacity: (1 - _drag * 2).clamp(0.0, 1.0) * 0.85,
                      inset: _thumb + 12,
                      // The label is centred, so the gap is too.
                      clearFrom: (c.maxWidth - labelW) / 2 - 10,
                      clearTo: (c.maxWidth + labelW) / 2 + 10,
                    ),
                  ),
                ],
                // Label fades as the fill passes it.
                Center(
                  child: Opacity(
                    opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                    child: Text(label, style: labelStyle),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: 6 + x,
                  child: GestureDetector(
                    key: const ValueKey('slide-thumb'),
                    onHorizontalDragStart: blocked
                        ? null
                        : (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: blocked
                        ? null
                        : (d) => setState(
                            () => _drag = (_drag + d.delta.dx / travelPx).clamp(
                              0.0,
                              1.0,
                            ),
                          ),
                    onHorizontalDragEnd: blocked
                        ? null
                        : (_) => _release(_drag),
                    onHorizontalDragCancel: blocked
                        ? null
                        : () => _release(_drag),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: blocked
                            ? FoxColors.textDisabled
                            : FoxColors.brandFox,
                        shape: BoxShape.circle,
                        boxShadow: _reduced ? null : Shadows.glow,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
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
        // Stop-drag is RIGHT→LEFT: the thumb RESTS at the right end and the
        // driver pulls it back toward the left; _drag tracks 0..1 travel.
        // (It used to rest at the LEFT end — covering the "Live" label — so a
        // leftward drag had nowhere to go and stopping was impossible on
        // device: the finger hit the screen edge ~250 px short of commit.)
        final x = _drag * travelPx;
        final paused = widget.status == WatchStatus.paused;
        final stateWord = paused ? 'Paused' : 'Live';
        final stateStyle = TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: FoxColors.cream,
        );
        final hintStyle = TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FoxColors.textDisabled,
        );
        // Where the label row ends: its left pad + dot + the two gaps + both
        // strings. Capped short of the resting thumb so the train always has
        // somewhere to march even at large font scales.
        final labelEnd =
            (Gap.md +
                    Gap.xs +
                    _PulsingDot.size +
                    Gap.sm * 2 +
                    _textWidth(context, stateWord, stateStyle) +
                    _textWidth(context, _stopHint, hintStyle) +
                    10)
                .clamp(0.0, c.maxWidth - _thumb - 60);
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
                    Text(stateWord, style: stateStyle),
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Opacity(
                        opacity: (1 - _drag * 2).clamp(0.0, 1.0),
                        child: Text(
                          _stopHint,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: hintStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Left-pointing train — the mirror of the go-live cue: "pull this
              // way to stop". It spans the track but dissolves across the
              // label's footprint; at full width the chevrons struck through
              // "slide back to stop" (device 2026-07-25).
              Positioned.fill(
                child: _MarchingChevrons(
                  reduced: _reduced,
                  reverse: true,
                  opacity: (1 - _drag * 2).clamp(0.0, 1.0) * 0.55,
                  inset: _thumb + 12,
                  // Label runs from the left edge, so the gap starts there.
                  clearFrom: 0,
                  clearTo: labelEnd,
                ),
              ),
              Positioned(
                left: 6 + (travelPx - x),
                child: GestureDetector(
                  key: const ValueKey('slide-stop-thumb'),
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) => setState(
                    () =>
                        _drag = (_drag - d.delta.dx / travelPx).clamp(0.0, 1.0),
                  ),
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
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
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

/// A translucent cream sheen sweeping the full width of the track — the "this
/// whole thing is draggable" cue. Deliberately faint: it should register as
/// glass catching the light, not as a second control fighting the orange fill.
/// Renders nothing under reduced motion.
class _GlassSweep extends StatefulWidget {
  const _GlassSweep({required this.reduced, required this.opacity});

  final bool reduced;
  final double opacity; // outer fade (driven by drag)

  @override
  State<_GlassSweep> createState() => _GlassSweepState();
}

class _GlassSweepState extends State<_GlassSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.repeat();
  }

  @override
  void didUpdateWidget(_GlassSweep old) {
    super.didUpdateWidget(old);
    if (widget.reduced && _c.isAnimating) _c.stop();
    if (!widget.reduced && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduced || widget.opacity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: LayoutBuilder(
          builder: (context, c) {
            // The band is wider than half the track, so the sheen reads as one
            // long pass rather than a small blob crossing.
            final bandWidth = c.maxWidth * 0.55;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                children: [
                  Positioned(
                    // Travel from fully off the left edge to fully off the
                    // right, so there's no pop-in at either end.
                    left: -bandWidth + _c.value * (c.maxWidth + bandWidth),
                    top: 0,
                    bottom: 0,
                    width: bandWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Orange, not cream. A gleam has to be brighter than
                        // what it sweeps, and the cream token now resolves to
                        // ink in light mode — which painted a gray smear across
                        // the track (device 2026-07-25). The brand orange is
                        // the one color that reads as light on the dark well
                        // AND as warmth on the pale one, and it reinforces the
                        // chevrons instead of fighting them.
                        gradient: LinearGradient(
                          colors: [
                            FoxColors.brandFox.withValues(alpha: 0),
                            FoxColors.brandFox.withValues(
                              alpha: 0.14 * widget.opacity,
                            ),
                            FoxColors.brandFox.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A marching train of orange chevrons — the "slide this way" cue. Chevrons
/// drift across the full width of the track (minus [inset] at each end so they
/// clear the thumb and the label) and fade in/out on a sin easing, so the row
/// reads as continuous motion rather than a handful of jumping glyphs. Points
/// right on the go-live track and left on the stop bar ([reverse]). Renders
/// nothing under reduced motion.
class _MarchingChevrons extends StatefulWidget {
  const _MarchingChevrons({
    required this.reduced,
    required this.opacity,
    required this.inset,
    this.reverse = false,
    this.clearFrom,
    this.clearTo,
  });

  final bool reduced;
  final double opacity; // outer fade (driven by drag)
  final double inset; // px kept clear at each end (thumb / label)
  final bool reverse; // true → point/march left (stop bar)

  /// The label's own footprint, in px from the track's left edge. The train
  /// dissolves across this span instead of marching through it — at full width
  /// the chevrons crossed the words and read as strikethrough (device
  /// 2026-07-25). Callers measure the label rather than guessing a fraction, so
  /// the gap tracks font scale and translated strings.
  final double? clearFrom;
  final double? clearTo;

  /// Soft edge on the gap, so chevrons fade into it rather than clipping.
  static const _feather = 14.0;

  /// Alpha ramp that ERASES the train between [clearFrom]/[clearTo] — painted
  /// through [BlendMode.dstOut], opaque black is what removes pixels.
  static Shader _gapShader(Rect r, double from, double to) {
    double at(double px) => (px / r.width).clamp(0.0, 1.0);
    return LinearGradient(
      colors: const [
        Colors.transparent,
        Colors.transparent,
        Colors.black,
        Colors.black,
        Colors.transparent,
        Colors.transparent,
      ],
      stops: [0, at(from - _feather), at(from), at(to), at(to + _feather), 1],
    ).createShader(r);
  }

  static const _iconSize = 26.0;
  static const _weight = 2.0; // overlapped stroke → bolder glyph
  static const _spacing = 44.0; // target px between chevrons

  @override
  State<_MarchingChevrons> createState() => _MarchingChevronsState();
}

class _MarchingChevronsState extends State<_MarchingChevrons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.repeat();
  }

  @override
  void didUpdateWidget(_MarchingChevrons old) {
    super.didUpdateWidget(old);
    if (widget.reduced && _c.isAnimating) _c.stop();
    if (!widget.reduced && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduced || widget.opacity <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: LayoutBuilder(
          builder: (context, c) {
            final band = (c.maxWidth - widget.inset * 2).clamp(
              _MarchingChevrons._spacing,
              double.infinity,
            );
            // One chevron per _spacing of track, so the train covers the whole
            // width on any screen instead of bunching at one end.
            final count = (band / _MarchingChevrons._spacing).round().clamp(
              2,
              12,
            );
            final from = widget.clearFrom;
            final to = widget.clearTo;
            final train = AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                children: [
                  for (var i = 0; i < count; i++)
                    () {
                      // Fractional progress of chevron i, wrapping 0..1. On the
                      // stop bar the train marches the other way.
                      final f = (_c.value + i / count) % 1.0;
                      final pos = widget.reverse ? (1 - f) * band : f * band;
                      return Positioned(
                        left: widget.inset + pos,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Opacity(
                            // Fade in then out across the band (glassy trail),
                            // but floored: an unfloored sine leaves most of the
                            // train near zero at any instant, so the direction
                            // never reads (device 2026-07-25).
                            opacity: (0.35 + 0.65 * math.sin(f * math.pi))
                                .clamp(0.0, 1.0),
                            // Two stacked glyphs, the back one thicker, fake a
                            // bold weight the icon font doesn't otherwise expose.
                            child: Stack(
                              children: [
                                Icon(
                                  widget.reverse
                                      ? Icons.chevron_left_rounded
                                      : Icons.chevron_right_rounded,
                                  size:
                                      _MarchingChevrons._iconSize +
                                      _MarchingChevrons._weight,
                                  color: FoxColors.brandFoxDeep,
                                ),
                                Icon(
                                  widget.reverse
                                      ? Icons.chevron_left_rounded
                                      : Icons.chevron_right_rounded,
                                  size: _MarchingChevrons._iconSize,
                                  color: FoxColors.brandFox,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            );
            if (from == null || to == null || to <= from) return train;
            return ShaderMask(
              blendMode: BlendMode.dstOut,
              shaderCallback: (r) => _MarchingChevrons._gapShader(r, from, to),
              child: train,
            );
          },
        ),
      ),
    );
  }
}

/// Width [text] will occupy in [style] at the current text scale. Used to size
/// the chevron train's gap around a label instead of hard-coding a fraction.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// Pulsing live dot; steady (no loop) under reduced motion / paused.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.reduced});
  final bool reduced;

  /// Laid-out width; callers measuring the label row need it.
  static const size = 9.0;

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
        width: _PulsingDot.size,
        height: _PulsingDot.size,
        decoration: BoxDecoration(
          color: FoxColors.brandFox,
          shape: BoxShape.circle,
          boxShadow: widget.reduced
              ? null
              : [
                  BoxShadow(
                    color: FoxColors.brandFox.withValues(
                      alpha: 0.3 + 0.4 * _c.value,
                    ),
                    blurRadius: 6 + 8 * _c.value,
                  ),
                ],
        ),
      ),
    );
  }
}
