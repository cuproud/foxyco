import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/garage.dart';
import '../settings/garage_controller.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_art.dart';

/// Home hero profile card (spec M6 §3.1): banded greeting (incl. 22–04
/// "Late shift" fix), active-vehicle line + fuel badge, premium VehicleArt on
/// a dark gradient stage. Hidden entirely until the driver gives a name.
/// Entrance fade+slide once; slow sheen loop after — both skipped when the OS
/// asks for reduced motion.
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  /// Greeting band for [hour] (spec M6 §3.1). The 22–04 night-driver fix:
  /// "Good morning" at 1 AM read as broken for people actually working.
  static String greetingFor(int hour) {
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Late shift';
  }

  static String _fuelBadge(FuelType fuel) {
    switch (fuel) {
      case FuelType.ev:
        return '⚡ EV';
      case FuelType.hybrid:
        return '♻ Hybrid';
      case FuelType.gas:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(driverNameProvider).trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final vehicle = ref.watch(activeVehicleProvider);

    final card = Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greetingFor(DateTime.now().hour)}, $name',
            style: const TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: FoxColors.cream,
            ),
          ),
          if (vehicle != null) ...[
            if (vehicle.vehicleLine.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      vehicle.vehicleLine,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_fuelBadge(vehicle.fuelType).isNotEmpty) ...[
                    const SizedBox(width: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: FoxColors.bgSurface2,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: FoxColors.borderSoft),
                      ),
                      child: Text(
                        _fuelBadge(vehicle.fuelType),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: VerdictColors.good,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: Gap.md),
            Center(
              child: VehicleArt(
                bodyType: vehicle.bodyType,
                color: Color(vehicle.colorValue),
                fuelType: vehicle.fuelType,
                width: 230,
              ),
            ),
          ],
        ],
      ),
    );

    // Bottom padding lives INSIDE the card widget so the home list only gains
    // spacing when the card actually shows (shrink stays truly zero-height).
    // Reduced motion: static card, no entrance, no sheen.
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
  late final _fade = CurvedAnimation(parent: _c, curve: Motion.curve);
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
