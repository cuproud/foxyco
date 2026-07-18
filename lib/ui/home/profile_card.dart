import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/driver_profile.dart';
import '../settings/profile_controller.dart';
import '../theme/tokens.dart';

/// Home hero profile card (spec M5 §3): time-aware greeting, vehicle line,
/// side-view silhouette tinted the profile color. Hidden entirely until the
/// driver gives a name. Entrance fade+slide once; slow sheen loop after —
/// both skipped when the OS asks for reduced motion.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  static String _greeting(String name, DateTime now) {
    final h = now.hour;
    final part = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$part, $name';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (!profile.hasName) return const SizedBox.shrink();

    final card = Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        boxShadow: Shadows.hero,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(profile.name.trim(), DateTime.now()),
                  style: const TextStyle(
                    fontFamily: FoxFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.cream,
                  ),
                ),
                if (profile.vehicleLine.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    profile.vehicleLine,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: FoxColors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          SizedBox(
            width: 96,
            height: 44,
            child: CustomPaint(
              painter: VehiclePainter(
                type: profile.vehicleType,
                color: Color(profile.vehicleColor),
              ),
            ),
          ),
        ],
      ),
    );

    // Bottom padding lives INSIDE the card widget so the home list only gains
    // spacing when the card actually shows (shrink stays truly zero-height).
    if (MediaQuery.of(context).disableAnimations) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: card,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: _AnimatedEntrance(child: _SheenLoop(child: card)),
    );
  }
}

/// One-shot fade + slide-up on first build.
class _AnimatedEntrance extends StatefulWidget {
  const _AnimatedEntrance({required this.child});
  final Widget child;

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final _slide =
      Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fade);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Slow low-opacity sheen sweeping the card — long period, subtle.
class _SheenLoop extends StatefulWidget {
  const _SheenLoop({required this.child});
  final Widget child;

  @override
  State<_SheenLoop> createState() => _SheenLoopState();
}

class _SheenLoopState extends State<_SheenLoop>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.5 + 3 * _c.value, -0.3),
          end: Alignment(-0.5 + 3 * _c.value, 0.3),
          colors: const [
            Colors.transparent,
            Color(0x14FFFFFF),
            Colors.transparent,
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Side-view vehicle silhouette: one painter, six path variants, filled with
/// the profile color + simple shading (darker underside, window tint). All
/// coordinates are fractions of the canvas so it scales with its box.
class VehiclePainter extends CustomPainter {
  VehiclePainter({required this.type, required this.color});
  final VehicleType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Path body;
    Path windows;

    switch (type) {
      case VehicleType.sedan:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..lineTo(0.10 * w, 0.55 * h)
          ..lineTo(0.28 * w, 0.50 * h)
          ..lineTo(0.38 * w, 0.28 * h)
          ..lineTo(0.68 * w, 0.28 * h)
          ..lineTo(0.80 * w, 0.50 * h)
          ..lineTo(0.95 * w, 0.58 * h)
          ..lineTo(0.95 * w, 0.75 * h)
          ..close();
        windows = Path()
          ..moveTo(0.40 * w, 0.32 * h)
          ..lineTo(0.66 * w, 0.32 * h)
          ..lineTo(0.75 * w, 0.48 * h)
          ..lineTo(0.32 * w, 0.48 * h)
          ..close();
      case VehicleType.suv:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.07 * w, 0.45 * h)
          ..lineTo(0.20 * w, 0.40 * h)
          ..lineTo(0.30 * w, 0.20 * h)
          ..lineTo(0.78 * w, 0.20 * h)
          ..lineTo(0.88 * w, 0.42 * h)
          ..lineTo(0.95 * w, 0.48 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.33 * w, 0.24 * h)
          ..lineTo(0.76 * w, 0.24 * h)
          ..lineTo(0.83 * w, 0.40 * h)
          ..lineTo(0.26 * w, 0.40 * h)
          ..close();
      case VehicleType.hatchback:
        body = Path()
          ..moveTo(0.05 * w, 0.75 * h)
          ..lineTo(0.09 * w, 0.52 * h)
          ..lineTo(0.25 * w, 0.48 * h)
          ..lineTo(0.36 * w, 0.26 * h)
          ..lineTo(0.72 * w, 0.24 * h)
          ..lineTo(0.90 * w, 0.52 * h)
          ..lineTo(0.92 * w, 0.75 * h)
          ..close();
        windows = Path()
          ..moveTo(0.38 * w, 0.30 * h)
          ..lineTo(0.70 * w, 0.29 * h)
          ..lineTo(0.82 * w, 0.48 * h)
          ..lineTo(0.30 * w, 0.46 * h)
          ..close();
      case VehicleType.pickup:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.07 * w, 0.48 * h)
          ..lineTo(0.16 * w, 0.44 * h)
          ..lineTo(0.24 * w, 0.24 * h)
          ..lineTo(0.50 * w, 0.24 * h)
          ..lineTo(0.54 * w, 0.46 * h)
          ..lineTo(0.95 * w, 0.46 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.27 * w, 0.28 * h)
          ..lineTo(0.47 * w, 0.28 * h)
          ..lineTo(0.50 * w, 0.42 * h)
          ..lineTo(0.20 * w, 0.42 * h)
          ..close();
      case VehicleType.van:
        body = Path()
          ..moveTo(0.05 * w, 0.78 * h)
          ..lineTo(0.06 * w, 0.30 * h)
          ..lineTo(0.16 * w, 0.18 * h)
          ..lineTo(0.88 * w, 0.18 * h)
          ..lineTo(0.95 * w, 0.34 * h)
          ..lineTo(0.95 * w, 0.78 * h)
          ..close();
        windows = Path()
          ..moveTo(0.18 * w, 0.24 * h)
          ..lineTo(0.86 * w, 0.24 * h)
          ..lineTo(0.90 * w, 0.36 * h)
          ..lineTo(0.14 * w, 0.36 * h)
          ..close();
      case VehicleType.motorbike:
        body = Path()
          ..moveTo(0.12 * w, 0.70 * h)
          ..lineTo(0.30 * w, 0.45 * h)
          ..lineTo(0.44 * w, 0.40 * h)
          ..lineTo(0.58 * w, 0.28 * h)
          ..lineTo(0.66 * w, 0.30 * h)
          ..lineTo(0.60 * w, 0.45 * h)
          ..lineTo(0.82 * w, 0.50 * h)
          ..lineTo(0.86 * w, 0.70 * h)
          ..lineTo(0.12 * w, 0.70 * h)
          ..close();
        windows = Path(); // no glass on a bike
    }

    // Body fill + darker underside shading.
    canvas.drawPath(body, Paint()..color = color);
    final underside = Path()
      ..addRect(Rect.fromLTRB(0, 0.60 * h, w, h))
      ..close();
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      underside,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    // Lighter roofline strip.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, 0.32 * h),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();
    // Window tint.
    canvas.drawPath(
      windows,
      Paint()..color = const Color(0xCC22303A),
    );
    // Wheels.
    final wheel = Paint()..color = const Color(0xFF1B1B1B);
    final hub = Paint()..color = const Color(0xFF8A8A8A);
    final r = 0.14 * h * 1.6;
    for (final cx in [0.24 * w, 0.76 * w]) {
      canvas.drawCircle(Offset(cx, 0.78 * h), r, wheel);
      canvas.drawCircle(Offset(cx, 0.78 * h), r * 0.45, hub);
    }
  }

  @override
  bool shouldRepaint(VehiclePainter old) =>
      old.type != type || old.color != color;
}
