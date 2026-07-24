import 'package:flutter/material.dart';

import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../theme/tokens.dart';

/// The floating verdict pill (references/foxyco_pill_v9.html — "split-color").
///
/// Two fused blocks: a verdict-colored block leading with the headline **$/km**
/// (the number that decides the verdict, so its color carries the call), fused
/// to a near-black block with the trip **km** and **$/hr**. A recessed seam and
/// glass sheen make it read as one compact HUD chip over the driver's map.
///
/// Plain widget, no plugin imports — renders identically in the overlay isolate
/// and an in-app preview, so it's buildable/eyeballable without a device.
class VerdictPill extends StatelessWidget {
  const VerdictPill({
    super.key,
    required this.payload,
    this.size,
    this.animate = true,
  });

  final OverlayPayload payload;

  /// Overrides [OverlayPayload.size]. The floating overlay forces
  /// [PillSize.small] to fit the compact draggable window.
  final PillSize? size;

  /// When false the plasma ring renders static (settings preview, tests) —
  /// the orbit loop never settles under pumpAndSettle and buys nothing there.
  final bool animate;

  // Pill-specific verdict fills (references/*pill* :root — a touch deeper than
  // the on-dark seg colors so the light block still reads on a bright map).
  static const _good = Color(0xFF39A96C);
  static const _ok = Color(0xFFE4A83C);
  static const _bad = Color(0xFFE56458);
  static const _unknown = Color(0xFF8895A7);

  Color get _rateColor => switch (payload.verdict) {
    Verdict.good => _good,
    Verdict.ok => _ok,
    Verdict.bad => _bad,
    Verdict.unknown => _unknown,
  };

  @override
  Widget build(BuildContext context) {
    final m = _metrics(size ?? payload.size);
    final perKm = '\$${payload.pricePerKm.toStringAsFixed(2)}';

    // Sheen goes from a lightened verdict color to the base — keeps the block
    // its verdict color (a plain white->transparent gradient would erase it,
    // since a BoxDecoration paints the gradient INSTEAD of `color`).
    final sheenTop = Color.lerp(_rateColor, Colors.white, 0.22)!;

    return Material(
      type: MaterialType.transparency,
      child: _PlasmaBorder(
        color: _rateColor,
        animate: animate,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            // One tight, neutral drop shadow. The old verdict-colored glow +
            // wide dark blur painted a smeary gradient across the overlay
            // window box over the map — looked like a dirty halo, not depth.
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E141C17),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colored rate block — the $/km headline, verdict-tinted.
              Container(
                padding: EdgeInsets.fromLTRB(
                  m.padH + 1,
                  m.padV,
                  m.padH - 1,
                  m.padV,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [sheenTop, _rateColor],
                    stops: const [0, 0.7],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      perKm,
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: m.rate + 1,
                        height: 1,
                        letterSpacing: -0.2,
                        color: const Color(0xFF141C17),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '/km',
                      style: TextStyle(
                        // Explicit family: the overlay isolate's MaterialApp has
                        // no theme, so an unset family fell back to Roboto and
                        // clashed with the Fraunces figure next to it.
                        fontFamily: FoxFonts.sans,
                        fontWeight: FontWeight.w600,
                        fontSize: m.unit,
                        letterSpacing: 0.2,
                        color: const Color(0xFF141C17).withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              // Dark info block — trip km + $/hr.
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: m.padH,
                  vertical: m.padV,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF203026),
                      Color(0xFF141C17),
                      Color(0xFF0C1310),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${payload.totalKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontFamily: FoxFonts.sans,
                        fontWeight: FontWeight.w700,
                        fontSize: m.sub,
                        // Pickup-near signal (references/*pill* "color only, no
                        // new element"): pickup at/under the driver's cutoff
                        // paints the km green, over paints it red. No pickup
                        // info → default cream.
                        color: switch (payload.pickupIsNear) {
                          true => const Color(0xFF5ECD90),
                          false => const Color(0xFFFF8A7E),
                          null => FoxColors.creamDim,
                        },
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (payload.pricePerHour > 0) ...[
                      SizedBox(width: m.gap),
                      Container(
                        width: 1,
                        height: m.sub,
                        color: const Color(0x52F4EFE1),
                      ),
                      SizedBox(width: m.gap),
                      Text(
                        '\$${payload.pricePerHour.toStringAsFixed(0)}/hr',
                        style: TextStyle(
                          fontFamily: FoxFonts.sans,
                          fontWeight: FontWeight.w700,
                          fontSize: m.sub,
                          // $/hr tinted by the driver's per-hour cut points
                          // (same "color only, no new element" rule as the
                          // pickup km). No cut points / no time → cream.
                          color: switch (payload.hourVerdict) {
                            Verdict.good => const Color(0xFF5ECD90),
                            Verdict.ok => const Color(0xFFF2C464),
                            Verdict.bad => const Color(0xFFFF8A7E),
                            _ => FoxColors.creamDim,
                          },
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _PillMetrics _metrics(PillSize size) => switch (size) {
    PillSize.small => const _PillMetrics(
      padH: 16,
      padV: 11,
      gap: 8,
      rate: 20,
      unit: 11,
      sub: 13.5,
    ),
    PillSize.medium => const _PillMetrics(
      padH: 18,
      padV: 12,
      gap: 10,
      rate: 22,
      unit: 12,
      sub: 15,
    ),
    PillSize.large => const _PillMetrics(
      padH: 22,
      padV: 15,
      gap: 12,
      rate: 27,
      unit: 14,
      sub: 18,
    ),
  };
}

class _PillMetrics {
  final double padH, padV, gap, rate, unit, sub;
  const _PillMetrics({
    required this.padH,
    required this.padV,
    required this.gap,
    required this.rate,
    required this.unit,
    required this.sub,
  });
}

/// Animated "plasma" ring around the pill, tinted by the verdict color: two
/// bright arcs orbit the stadium outline over a faint static ring, with a soft
/// outer glow. Living, not static — the driver's eye catches the motion, and
/// the color repeats the verdict so the call reads even before the number.
///
/// Cost-conscious: one repaint-boundary'd CustomPaint on a 2.4 s loop, arcs
/// drawn with a sweep gradient — no shaders/blur layers beyond two blurred
/// strokes. Honors reduced motion by freezing the orbit (static tinted ring
/// keeps the color signal).
class _PlasmaBorder extends StatefulWidget {
  const _PlasmaBorder({
    required this.color,
    required this.animate,
    required this.child,
  });
  final Color color;
  final bool animate;
  final Widget child;

  @override
  State<_PlasmaBorder> createState() => _PlasmaBorderState();
}

class _PlasmaBorderState extends State<_PlasmaBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// Ring thickness + glow bleed the child is inset by, so the pill keeps its
  /// exact size and the ring paints in the margin (overlay window already has
  /// slack around the pill).
  static const _inset = 3.0;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if ((reduced || !widget.animate) && _c.isAnimating) _c.stop();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _PlasmaPainter(color: widget.color, t: _c.value),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PlasmaPainter extends CustomPainter {
  const _PlasmaPainter({required this.color, required this.t});
  final Color color;
  final double t; // 0..1 orbit phase

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ).deflate(1);
    final ring = Path()..addRRect(rrect);

    // Faint static base ring — keeps a continuous outline between the arcs.
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.35),
    );

    // Two orbiting arcs, 180° apart, via a rotated sweep gradient masked to
    // the stroke. The gradient's hot spot fades over ~a quarter turn, which
    // reads as a comet with a tail sliding around the stadium.
    final center = size.center(Offset.zero);
    final sweep = SweepGradient(
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.95),
        Colors.white.withValues(alpha: 0.9),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.85),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.08, 0.10, 0.12, 0.22, 0.50, 0.60, 0.72],
      transform: GradientRotation(t * 2 * 3.14159265),
    ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    // Soft glow pass under the crisp arc.
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..shader = sweep
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..shader = sweep,
    );
  }

  @override
  bool shouldRepaint(_PlasmaPainter old) => old.t != t || old.color != color;
}
