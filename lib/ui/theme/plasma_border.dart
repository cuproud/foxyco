import 'package:flutter/material.dart';

/// An animated plasma outline shared by the floating verdict pill and live
/// surfaces in the app: two bright arcs orbit a faint continuous ring.
///
/// [borderRadius] is optional because a stadium pill derives its radius from
/// its height, while cards use a fixed design-token radius. Reduced-motion
/// mode freezes the arcs but preserves the colored status outline.
class PlasmaBorder extends StatefulWidget {
  const PlasmaBorder({
    super.key,
    required this.color,
    required this.child,
    this.animate = true,
    this.borderRadius,
    this.inset = 3,
  });

  final Color color;
  final Widget child;
  final bool animate;
  final double? borderRadius;

  /// Ring thickness plus glow bleed reserved around [child].
  final double inset;

  @override
  State<PlasmaBorder> createState() => _PlasmaBorderState();
}

class _PlasmaBorderState extends State<PlasmaBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PlasmaBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    widget.animate ? _controller.repeat() : _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if ((reduced || !widget.animate) && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduced && widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          foregroundPainter: PlasmaBorderPainter(
            color: widget.color,
            phase: _controller.value,
            borderRadius: widget.borderRadius,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.inset),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Painter is public so its static and animated states can be tested directly.
class PlasmaBorderPainter extends CustomPainter {
  const PlasmaBorderPainter({
    required this.color,
    required this.phase,
    this.borderRadius,
  });

  final Color color;
  final double phase;
  final double? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = borderRadius ?? size.height / 2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(1);
    final ring = Path()..addRRect(rrect);

    // Faint static base ring keeps a continuous outline between the arcs.
    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.35),
    );

    // Two orbiting arcs, 180° apart. Each hot spot fades into a short tail.
    final center = size.center(Offset.zero);
    final sweep = SweepGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.95),
        Colors.white.withValues(alpha: 0.9),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.85),
        color.withValues(alpha: 0),
      ],
      stops: const [0, 0.08, 0.10, 0.12, 0.22, 0.50, 0.60, 0.72],
      transform: GradientRotation(phase * 2 * 3.14159265),
    ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    // A soft glow underneath a crisp moving stroke.
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
  bool shouldRepaint(PlasmaBorderPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}
