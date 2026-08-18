import 'package:flutter/material.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import 'tokens.dart';

/// The garage vehicle thumbnail: a Foxy illustration matching the body type
/// (art set 2026-07-23 — one colorful render per style, replacing the old
/// black/red two-tone silhouettes; PNGs are autocropped to the artwork, so the
/// vehicle FILLS the frame). The driver's chosen paint [color] no longer tints
/// the art (these are shaded illustrations); it lives on as the text label in
/// [Vehicle.vehicleLine]. Fuel type still rides as a small corner badge.
///
/// The art fills whatever box the parent gives it (wrap in an [AspectRatio] or
/// bounded [SizedBox] to control its footprint). When the parent is unbounded,
/// it falls back to a square [size]×[size] box. Body aspect ratios vary widely
/// (a pickup is ~2.5:1, a scooter ~0.7:1), so [BoxFit.contain] does the fitting
/// rather than any hardcoded box shape — scaled down for the two-wheelers by
/// [_massFraction] so a scooter doesn't render as tall as a van.
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

  /// Fallback footprint + fuel-badge scale reference when the parent doesn't
  /// bound the widget. Ignored for the fill when the parent IS bounded.
  final double size;

  /// How much of the parent box the art is allowed to occupy.
  ///
  /// Most art is a wide side profile (~2.4:1), so `contain` binds on width and
  /// every one lands at a similar on-screen size. Some renders aren't: the
  /// two-wheelers are ~1.1:1 (a standing scooter ~0.66:1) and the off-road /
  /// premium art is a 3/4 view at ~1.2–1.7:1. For those `contain` binds on
  /// HEIGHT instead, so they render full-box-height — a scooter came out taller
  /// than a van (device 2026-07-24). Shrinking their box restores the size order
  /// without touching the art.
  ///
  /// Calibration knob, tuned by eye at the editor's 1.7:1 preview — the numbers
  /// track each asset's real aspect ratio, so re-check them if the art set is
  /// re-rendered. They hold at badge sizes since the scale is proportional.
  static double _massFraction(VehicleType t) => switch (t) {
    VehicleType.bike || VehicleType.motorbike || VehicleType.eBike => 0.72,
    VehicleType.eScooter => 0.62,
    // 3/4-view renders: taller than a side profile, but not 40% taller.
    VehicleType.offRoad || VehicleType.premium => 0.85,
    _ => 1.0,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bounded = c.maxWidth.isFinite && c.maxHeight.isFinite;
        // Scale the fuel badge to the actual box (its short side) when bounded.
        final ref = bounded ? c.biggest.shortestSide : size;
        final stack = Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                widthFactor: _massFraction(bodyType),
                heightFactor: _massFraction(bodyType),
                child: Image.asset(
                  'assets/vehicles/${bodyType.assetName}.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
            if (fuelType != FuelType.gas)
              Positioned(
                top: -4,
                right: -2,
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
                    size: (ref * 0.22).clamp(12.0, 26.0),
                    color: VerdictColors.good,
                  ),
                ),
              ),
          ],
        );
        return bounded
            ? stack
            : SizedBox(width: size, height: size, child: stack);
      },
    );
  }
}
