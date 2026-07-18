import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../settings/garage_controller.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_art.dart';

/// Cold-start splash (spec M6 §10). A single [AnimationController] drives the
/// wordmark fade (0–0.25) and the car drive-in (0.15–0.75) over 1.8s, then
/// `context.go('/')`. A hard 3s ceiling [Timer] force-navigates even if the
/// controller stalls — the splash never traps. Reduced motion skips the
/// animation: the wordmark shows instantly and a short timer moves on.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _ceiling;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Ceiling armed before anything can fail — splash always exits.
    _ceiling = Timer(const Duration(seconds: 3), _go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = MediaQuery.of(context).disableAnimations;
      if (reduced) {
        Timer(const Duration(milliseconds: 500), _go);
      } else {
        _c.forward().whenComplete(_go);
      }
    });
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _ceiling?.cancel();
    context.go('/');
  }

  @override
  void dispose() {
    _ceiling?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final bodyType =
        ref.watch(activeVehicleProvider)?.bodyType ?? VehicleType.sedan;

    return Scaffold(
      backgroundColor: FoxColors.bgBase,
      body: reduced
          ? const Center(child: _Wordmark(opacity: 1))
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final wordmark = const Interval(
                  0.0,
                  0.25,
                  curve: Curves.easeOut,
                ).transform(_c.value);
                final drive = const Interval(
                  0.15,
                  0.75,
                  curve: Curves.easeOutCubic,
                ).transform(_c.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.25),
                      child: _Wordmark(opacity: wordmark),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.35),
                      child: CustomPaint(
                        size: const Size(320, 120),
                        painter: _SplashScenePainter(
                          progress: drive,
                          shimmer: _c.value,
                          bodyType: bodyType,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: const Text(
        'FoxyCo',
        style: TextStyle(
          fontFamily: FoxFonts.display,
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: FoxColors.cream,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

/// Car silhouette drives in from the left with a headlight beam; a road line
/// shimmers underneath. The silhouette reuses [VehicleArtPainter] with a flat
/// dark tint — at this size the shape reads, not the detail.
class _SplashScenePainter extends CustomPainter {
  const _SplashScenePainter({
    required this.progress,
    required this.shimmer,
    required this.bodyType,
  });

  final double progress; // 0..1 drive-in
  final double shimmer; // 0..1 whole-sequence t
  final VehicleType bodyType;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Road line with a moving shimmer highlight.
    final roadY = 0.88 * h;
    canvas.drawLine(
      Offset(0.05 * w, roadY),
      Offset(0.95 * w, roadY),
      Paint()
        ..color = FoxColors.cream.withValues(alpha: 0.12)
        ..strokeWidth = 2,
    );
    final shimmerX = (0.05 + 0.9 * shimmer) * w;
    canvas.drawLine(
      Offset(shimmerX - 0.08 * w, roadY),
      Offset(shimmerX + 0.08 * w, roadY),
      Paint()
        ..color = FoxColors.cream.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Car drives in: x from off-screen-left to centered.
    const carW = 150.0;
    const carH = carW * 0.48;
    final carX = -carW + (0.5 * w - carW / 2 + carW) * progress;
    canvas.save();
    canvas.translate(carX, roadY - carH - 8);
    VehicleArtPainter(
      bodyType: bodyType,
      color: const Color(0xFF2A3A31), // silhouette tint
      fuelType: FuelType.gas,
    ).paint(canvas, const Size(carW, carH));
    canvas.restore();

    // Headlight beam off the car's nose, fading out during the last stretch.
    final noseX = carX + carW * 0.95;
    final noseY = roadY - carH * 0.35;
    final beamAlpha = (0.30 * (1 - (progress - 0.6).clamp(0, 0.4) / 0.4)).clamp(
      0.0,
      0.30,
    );
    final beam = Path()
      ..moveTo(noseX, noseY - 14)
      ..lineTo(noseX + 0.35 * w, noseY - 4)
      ..lineTo(noseX + 0.35 * w, noseY + 18)
      ..lineTo(noseX, noseY + 14)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          colors: [
            // warm headlight-beam gradient — splash painter, intentionally off-token
            const Color(0xFFFFE9B8).withValues(alpha: beamAlpha),
            const Color(0x00FFE9B8),
          ],
        ).createShader(Rect.fromLTWH(noseX, noseY - 14, 0.35 * w, 32)),
    );
  }

  @override
  bool shouldRepaint(_SplashScenePainter old) =>
      old.progress != progress ||
      old.shimmer != shimmer ||
      old.bodyType != bodyType;
}
