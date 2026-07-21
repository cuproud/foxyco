import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import 'tokens.dart';

/// Side-profile vector silhouette tinted by the vehicle's color, with a cream
/// rim-light and soft ground shadow to sit in the dark showroom. Third take on
/// garage art: painted VehicleArt (rejected 2026-07-20), icon chip (rejected
/// 2026-07-21) — this one keeps shapes minimal so they read at 44dp.
class VehicleBadge extends StatelessWidget {
  const VehicleBadge({
    super.key,
    required this.bodyType,
    required this.color,
    this.fuelType = FuelType.gas,
    this.size = 44,
  });

  final VehicleType bodyType;
  final Color color;
  final FuelType fuelType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(size * 1.9, size),
          painter: _SilhouettePainter(bodyType: bodyType, color: color),
        ),
        if (fuelType != FuelType.gas)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: FoxColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: FoxColors.border),
              ),
              child: Icon(
                fuelType == FuelType.ev
                    ? Icons.bolt_rounded
                    : Icons.recycling_rounded,
                size: size * 0.32,
                color: VerdictColors.good,
              ),
            ),
          ),
      ],
    );
  }
}

/// Body + wheels in normalized 190×100 coordinate space, scaled to the canvas.
/// Body: vertical gradient of the vehicle color (lit roof → shadowed sill),
/// thin cream stroke on the whole outline as the rim light, elliptical ground
/// shadow underneath. Wheels: dark discs with a color-tinted hub ring.
class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter({required this.bodyType, required this.color});

  final VehicleType bodyType;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 190, sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    // Ground shadow first, under everything.
    canvas.drawOval(
      const Rect.fromLTWH(15, 82, 160, 14),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final body = _bodyPath(bodyType);
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
          stops: const [0, 0.45, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 190, 90)),
    );
    // Rim light — thin cream stroke reads as showroom lighting on dark.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = FoxColors.cream.withValues(alpha: 0.55),
    );

    // Window band: darkened inset strip in the cabin area per body type.
    final win = _windowPath(bodyType);
    if (win != null) {
      canvas.drawPath(
        win,
        Paint()..color = Colors.black.withValues(alpha: 0.42),
      );
    }

    // Wheels (motorbike positions differ).
    final wheels = bodyType == VehicleType.motorbike
        ? const [Offset(45, 78), Offset(145, 78)]
        : const [Offset(52, 80), Offset(140, 80)];
    final wheelR = bodyType == VehicleType.motorbike ? 16.0 : 13.0;
    for (final c in wheels) {
      canvas.drawCircle(c, wheelR, Paint()..color = const Color(0xFF10100E));
      canvas.drawCircle(
        c,
        wheelR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = FoxColors.cream.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        c,
        wheelR * 0.42,
        Paint()..color = Color.lerp(color, Colors.white, 0.25)!,
      );
    }

    canvas.restore();
  }

  /// Closed side-profile outline, nose pointing right, in 190×100 space.
  /// Baseline (sill) sits at y≈74 so wheels at y≈80 half-overlap it.
  static Path _bodyPath(VehicleType t) {
    final p = Path();
    switch (t) {
      case VehicleType.sedan:
        p.moveTo(12, 68);
        p.cubicTo(12, 58, 20, 52, 38, 50); // trunk
        p.cubicTo(52, 34, 66, 28, 92, 28); // rear glass → roof
        p.cubicTo(112, 28, 124, 34, 136, 48); // windshield
        p.cubicTo(160, 50, 176, 56, 178, 66); // hood → nose
        p.cubicTo(179, 72, 176, 74, 170, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 72, 12, 68);
      case VehicleType.suv:
        p.moveTo(12, 66);
        p.cubicTo(12, 50, 16, 42, 30, 40); // tall tail
        p.cubicTo(36, 26, 48, 22, 96, 22); // boxy roof
        p.cubicTo(122, 22, 132, 27, 142, 40);
        p.cubicTo(162, 43, 176, 52, 178, 64);
        p.cubicTo(179, 71, 176, 74, 170, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 72, 12, 66);
      case VehicleType.hatchback:
        p.moveTo(14, 66);
        p.cubicTo(14, 46, 22, 34, 44, 30); // steep hatch
        p.cubicTo(70, 26, 96, 26, 112, 30);
        p.cubicTo(128, 34, 136, 42, 144, 50);
        p.cubicTo(162, 52, 174, 58, 176, 66);
        p.cubicTo(177, 72, 174, 74, 168, 74);
        p.lineTo(22, 74);
        p.cubicTo(16, 74, 14, 72, 14, 66);
      case VehicleType.pickup:
        p.moveTo(12, 64);
        p.lineTo(12, 46); // bed wall
        p.lineTo(84, 46); // bed rail
        p.lineTo(88, 26); // cab rear
        p.cubicTo(104, 22, 120, 24, 130, 40); // cab + windshield
        p.cubicTo(156, 42, 174, 52, 177, 63);
        p.cubicTo(178, 71, 175, 74, 169, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 71, 12, 64);
      case VehicleType.van:
        p.moveTo(12, 64);
        p.cubicTo(12, 34, 14, 24, 28, 22); // tall flat tail
        p.lineTo(118, 22); // long roof
        p.cubicTo(140, 22, 152, 32, 162, 48); // raked front
        p.cubicTo(172, 52, 177, 58, 178, 65);
        p.cubicTo(178, 71, 175, 74, 169, 74);
        p.lineTo(20, 74);
        p.cubicTo(14, 74, 12, 71, 12, 64);
      case VehicleType.motorbike:
        // Frame + tank + seat as one lowrider sweep; wheels dominate.
        p.moveTo(28, 66);
        p.cubicTo(34, 54, 48, 50, 62, 52); // tail + seat
        p.cubicTo(80, 42, 100, 40, 116, 46); // tank
        p.cubicTo(130, 40, 142, 44, 152, 56); // bars → front fork top
        p.cubicTo(156, 62, 152, 68, 144, 68);
        p.cubicTo(120, 74, 70, 74, 40, 72);
        p.cubicTo(32, 72, 26, 70, 28, 66);
    }
    p.close();
    return p;
  }

  /// Cabin glass band; null for the motorbike.
  static Path? _windowPath(VehicleType t) {
    switch (t) {
      case VehicleType.sedan:
        return Path()
          ..moveTo(54, 46)
          ..cubicTo(62, 34, 76, 31, 92, 31)
          ..cubicTo(110, 31, 122, 36, 130, 46)
          ..close();
      case VehicleType.suv:
        return Path()
          ..moveTo(38, 40)
          ..cubicTo(42, 28, 52, 26, 96, 26)
          ..cubicTo(118, 26, 128, 30, 136, 40)
          ..close();
      case VehicleType.hatchback:
        return Path()
          ..moveTo(36, 42)
          ..cubicTo(46, 32, 70, 30, 100, 32)
          ..cubicTo(118, 34, 130, 40, 138, 48)
          ..lineTo(36, 48)
          ..close();
      case VehicleType.pickup:
        return Path()
          ..moveTo(92, 42)
          ..lineTo(94, 29)
          ..cubicTo(104, 26, 116, 28, 124, 40)
          ..close();
      case VehicleType.van:
        return Path()
          ..moveTo(96, 40)
          ..lineTo(96, 26)
          ..lineTo(118, 26)
          ..cubicTo(134, 26, 144, 34, 152, 46)
          ..lineTo(96, 46)
          ..close();
      case VehicleType.motorbike:
        return null;
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.bodyType != bodyType || old.color != color;
}
