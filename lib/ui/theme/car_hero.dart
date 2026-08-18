import 'package:flutter/material.dart';

/// The Foxy showroom car (brand art set `foxy_car_assets_v1`, 2026-07-26).
///
/// Two pre-aligned PNGs on one 1536×1024 canvas: the car/fox core, and a
/// per-theme glow/shadow layer BEHIND it. The core is byte-identical between
/// themes, so only the back layer switches.
///
/// The art has no lights-off variant, so [glow] is the whole animated story —
/// it carries the offline→live "the car wakes up" beat that the old 15-layer
/// stealth→reveal crossfade used to.
class CarHero extends StatelessWidget {
  const CarHero({super.key, required this.glow, required this.onDark});

  /// Back-layer opacity, 0..1. Home lerps it on going live; splash flickers it
  /// on like a cold start.
  final double glow;

  /// Which back layer: the dark theme's warm glow, or the light theme's plain
  /// shadow.
  final bool onDark;

  /// Shared canvas aspect of every layer.
  static const canvas = 1536 / 1024;

  /// The car body on its own — [HeroStage] uses it as the reflection-sweep mask.
  static const coreAsset = 'assets/car/$_core.png';

  static const _core = 'foxy_car_core';
  static const _glowDark = 'foxy_car_glow_dark';
  static const _shadowLight = 'foxy_car_shadow_light';

  /// All layer asset basenames — splash uses this to precache.
  static const layerNames = [_core, _glowDark, _shadowLight];

  @override
  Widget build(BuildContext context) {
    // Decorative — stacked images are noise to screen readers.
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: canvas,
        child: LayoutBuilder(
          builder: (context, c) {
            // Decode at display resolution, not the asset's 1536 px.
            final cacheW =
                (c.maxWidth * MediaQuery.of(context).devicePixelRatio).round();
            Widget layer(String name, double opacity) => Image.asset(
              'assets/car/$name.png',
              fit: BoxFit.contain,
              cacheWidth: cacheW,
              gaplessPlayback: true,
              // Image's own opacity paints with alpha directly — an Opacity
              // widget here would saveLayer every frame of the tween.
              opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                if (glow > 0.004)
                  layer(onDark ? _glowDark : _shadowLight, glow),
                layer(_core, 1),
              ],
            );
          },
        ),
      ),
    );
  }
}
