import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';

/// Layered premium car art (spec M6 §7). Rendered as vector so the same
/// painter scales hero (230w) → thumb (72w) → splash without extra assets.
/// PNGs 220×106 (≈0.48 aspect) are the later fallback; swap happens inside
/// [VehicleArt] only. All painter coordinates are fractional (w, h).
class VehicleArt extends StatelessWidget {
  const VehicleArt({
    super.key,
    required this.bodyType,
    required this.color,
    this.fuelType = FuelType.gas,
    this.width = 220,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.48,
      child: CustomPaint(
        painter: VehicleArtPainter(
          bodyType: bodyType,
          color: color,
          fuelType: fuelType,
        ),
      ),
    );
  }
}

/// Layer order (spec M6 §7): ground shadow → body gradient → roof highlight →
/// glass + reflection streak → wheels → seams/handles/lights → fuel badge.
/// Coordinates are fractions (w, h); silhouettes lean 3/4 via a deeper
/// front (right) end and skewed glass, matching the reference cards' depth.
class VehicleArtPainter extends CustomPainter {
  const VehicleArtPainter({
    required this.bodyType,
    required this.color,
    required this.fuelType,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final (body, glass, wheels) = _silhouette(w, h);

    // 1. Ground shadow — soft blurred ellipse under car.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * w, 0.92 * h),
        width: 0.86 * w,
        height: 0.10 * h,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. Body — vertical gradient (light roof → base color → shaded rocker).
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );

    // 3. Roofline/hood highlight sweep, clipped to body.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTRB(0.15 * w, 0, 0.75 * w, 0.45 * h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(0.15 * w, 0, 0.75 * w, 0.45 * h)),
    );
    // Rocker-panel darkening near ground.
    canvas.drawRect(
      Rect.fromLTRB(0, 0.72 * h, w, h),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();

    // 4. Glass — dark blue-grey with diagonal reflection streak.
    if (!glass.getBounds().isEmpty) {
      canvas.drawPath(glass, Paint()..color = const Color(0xE61C2733));
      canvas.save();
      canvas.clipPath(glass);
      final gb = glass.getBounds();
      canvas.drawPath(
        Path()
          ..moveTo(gb.left + gb.width * 0.15, gb.top)
          ..lineTo(gb.left + gb.width * 0.35, gb.top)
          ..lineTo(gb.left + gb.width * 0.20, gb.bottom)
          ..lineTo(gb.left, gb.bottom)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.14),
      );
      canvas.restore();
    }

    // 5. Wheels — tire ring, rim spoke hints, hub dot.
    final tire = Paint()..color = const Color(0xFF15171A);
    final rim = Paint()
      ..color = const Color(0xFFAAB2BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.022 * w;
    final hub = Paint()..color = const Color(0xFF5F6770);
    for (final c in wheels) {
      final center = Offset(c.dx * w, c.dy * h);
      final r = 0.085 * w;
      canvas.drawCircle(center, r, tire);
      canvas.drawCircle(center, r * 0.62, rim);
      for (var i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * 3.14159 * 2 / 5);
        canvas.drawLine(
          Offset.zero,
          Offset(0, -r * 0.58),
          Paint()
            ..color = const Color(0xFF737B85)
            ..strokeWidth = 0.010 * w,
        );
        canvas.restore();
      }
      canvas.drawCircle(center, r * 0.16, hub);
    }

    // 6. Seams / door handle / lights.
    canvas.save();
    canvas.clipPath(body);
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0.52 * w, 0.42 * h),
      Offset(0.50 * w, 0.74 * h),
      seam,
    );
    // Door handle highlight.
    canvas.drawLine(
      Offset(0.55 * w, 0.50 * h),
      Offset(0.61 * w, 0.50 * h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.012 * w
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    // Headlight (front = right), taillight (rear = left).
    canvas.drawCircle(
      Offset(0.945 * w, 0.55 * h),
      0.020 * w,
      Paint()
        ..color = const Color(0xFFFFE9B8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(0.055 * w, 0.52 * h),
      0.016 * w,
      Paint()
        ..color = const Color(0xFFE8493F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 7. Fuel badge near rear wheel (spec: EV bolt, hybrid two-tone dot).
    if (fuelType == FuelType.ev) {
      final c = Offset(0.155 * w, 0.38 * h);
      canvas.drawCircle(c, 0.045 * w, Paint()..color = const Color(0xFF1D2B22));
      final bolt = Path()
        ..moveTo(c.dx + 0.010 * w, c.dy - 0.030 * w)
        ..lineTo(c.dx - 0.014 * w, c.dy + 0.004 * w)
        ..lineTo(c.dx - 0.001 * w, c.dy + 0.004 * w)
        ..lineTo(c.dx - 0.010 * w, c.dy + 0.030 * w)
        ..lineTo(c.dx + 0.014 * w, c.dy - 0.004 * w)
        ..lineTo(c.dx + 0.001 * w, c.dy - 0.004 * w)
        ..close();
      canvas.drawPath(bolt, Paint()..color = const Color(0xFF6FE3A1));
    } else if (fuelType == FuelType.hybrid) {
      final c = Offset(0.155 * w, 0.38 * h);
      canvas.drawCircle(c, 0.028 * w, Paint()..color = const Color(0xFF6FE3A1));
      canvas.drawCircle(
        c,
        0.028 * w,
        Paint()
          ..color = const Color(0xFF1D2B22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012 * w,
      );
    }
  }

  /// Returns (body path, glass path, wheel centers as fractions) per body type.
  (Path, Path, List<Offset>) _silhouette(double w, double h) {
    Path body;
    Path glass;
    var wheels = const [Offset(0.26, 0.82), Offset(0.78, 0.82)];

    switch (bodyType) {
      case VehicleType.sedan:
        body = Path()
          ..moveTo(0.04 * w, 0.74 * h)
          ..quadraticBezierTo(0.03 * w, 0.56 * h, 0.12 * w, 0.52 * h)
          ..lineTo(0.30 * w, 0.48 * h)
          ..quadraticBezierTo(0.38 * w, 0.24 * h, 0.52 * w, 0.22 * h)
          ..quadraticBezierTo(0.66 * w, 0.22 * h, 0.74 * w, 0.44 * h)
          ..lineTo(0.90 * w, 0.50 * h)
          ..quadraticBezierTo(0.97 * w, 0.54 * h, 0.96 * w, 0.74 * h)
          ..close();
        glass = Path()
          ..moveTo(0.38 * w, 0.28 * h)
          ..quadraticBezierTo(0.52 * w, 0.26 * h, 0.62 * w, 0.28 * h)
          ..lineTo(0.70 * w, 0.44 * h)
          ..lineTo(0.33 * w, 0.46 * h)
          ..close();
      case VehicleType.suv:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.44 * h)
          ..quadraticBezierTo(0.08 * w, 0.38 * h, 0.18 * w, 0.36 * h)
          ..quadraticBezierTo(0.26 * w, 0.16 * h, 0.42 * w, 0.15 * h)
          ..lineTo(0.72 * w, 0.15 * h)
          ..quadraticBezierTo(0.82 * w, 0.18 * h, 0.87 * w, 0.40 * h)
          ..quadraticBezierTo(0.96 * w, 0.44 * h, 0.96 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.31 * w, 0.20 * h)
          ..lineTo(0.72 * w, 0.20 * h)
          ..lineTo(0.80 * w, 0.38 * h)
          ..lineTo(0.24 * w, 0.38 * h)
          ..close();
      case VehicleType.hatchback:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..quadraticBezierTo(0.04 * w, 0.50 * h, 0.14 * w, 0.44 * h)
          ..quadraticBezierTo(0.24 * w, 0.22 * h, 0.44 * w, 0.20 * h)
          ..lineTo(0.62 * w, 0.20 * h)
          ..quadraticBezierTo(0.80 * w, 0.24 * h, 0.88 * w, 0.48 * h)
          ..quadraticBezierTo(0.95 * w, 0.52 * h, 0.94 * w, 0.75 * h)
          ..close();
        glass = Path()
          ..moveTo(0.26 * w, 0.26 * h)
          ..lineTo(0.60 * w, 0.25 * h)
          ..lineTo(0.76 * w, 0.44 * h)
          ..lineTo(0.20 * w, 0.44 * h)
          ..close();
      case VehicleType.pickup:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.46 * h)
          ..lineTo(0.34 * w, 0.44 * h)
          ..lineTo(0.38 * w, 0.20 * h)
          ..lineTo(0.62 * w, 0.20 * h)
          ..quadraticBezierTo(0.72 * w, 0.22 * h, 0.76 * w, 0.44 * h)
          ..quadraticBezierTo(0.94 * w, 0.46 * h, 0.95 * w, 0.56 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.42 * w, 0.24 * h)
          ..lineTo(0.60 * w, 0.24 * h)
          ..lineTo(0.66 * w, 0.42 * h)
          ..lineTo(0.40 * w, 0.42 * h)
          ..close();
      case VehicleType.van:
        body = Path()
          ..moveTo(0.04 * w, 0.78 * h)
          ..lineTo(0.05 * w, 0.28 * h)
          ..quadraticBezierTo(0.06 * w, 0.14 * h, 0.20 * w, 0.13 * h)
          ..lineTo(0.80 * w, 0.13 * h)
          ..quadraticBezierTo(0.92 * w, 0.16 * h, 0.95 * w, 0.36 * h)
          ..lineTo(0.96 * w, 0.78 * h)
          ..close();
        glass = Path()
          ..moveTo(0.16 * w, 0.20 * h)
          ..lineTo(0.84 * w, 0.20 * h)
          ..lineTo(0.89 * w, 0.36 * h)
          ..lineTo(0.13 * w, 0.36 * h)
          ..close();
      case VehicleType.motorbike:
        body = Path()
          ..moveTo(0.14 * w, 0.66 * h)
          ..quadraticBezierTo(0.24 * w, 0.42 * h, 0.42 * w, 0.40 * h)
          ..quadraticBezierTo(0.52 * w, 0.24 * h, 0.62 * w, 0.24 * h)
          ..lineTo(0.68 * w, 0.30 * h)
          ..quadraticBezierTo(0.62 * w, 0.44 * h, 0.72 * w, 0.48 * h)
          ..quadraticBezierTo(0.84 * w, 0.52 * h, 0.85 * w, 0.66 * h)
          ..close();
        glass = Path();
        wheels = const [Offset(0.22, 0.78), Offset(0.80, 0.78)];
    }

    return (body, glass, wheels);
  }

  @override
  bool shouldRepaint(VehicleArtPainter old) =>
      old.bodyType != bodyType ||
      old.color != color ||
      old.fuelType != fuelType;
}
