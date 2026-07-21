import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import 'tokens.dart';

/// Small vector vehicle badge: body-type icon on a chip tinted by the
/// vehicle's color. Replaced the painted VehicleArt silhouettes (device
/// feedback 2026-07-20 — "weird images"); the photographic car hero owns
/// the big showroom render now, this stays a crisp identity mark.
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

  static IconData iconFor(VehicleType t) => switch (t) {
    VehicleType.sedan => Icons.directions_car_rounded,
    VehicleType.suv => Icons.directions_car_filled_rounded,
    VehicleType.hatchback => Icons.time_to_leave_rounded,
    VehicleType.pickup => Icons.local_shipping_rounded,
    VehicleType.van => Icons.airport_shuttle_rounded,
    VehicleType.motorbike => Icons.two_wheeler_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(
            iconFor(bodyType),
            size: size * 0.55,
            color: Color.lerp(color, FoxColors.cream, 0.35),
          ),
        ),
        if (fuelType != FuelType.gas)
          Positioned(
            right: -4,
            bottom: -4,
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
