import 'package:flutter/material.dart';

/// Layered photographic car hero (references/car/foxyco_hero_home (1).html).
///
/// All PNGs in assets/car/ share one 1536×1024 canvas and are pre-aligned —
/// compositing is a plain [Stack] of full-bleed images with per-layer opacity.
/// [CarHeroState] holds one opacity per layer; splash and home drive it from
/// their own animations and [CarHeroState.lerp] crossfades between presets.
class CarHeroState {
  const CarHeroState({
    this.shadow = 0,
    this.stealthBacklight = 0,
    this.fogRear = 0,
    this.carStealth = 0,
    this.fogFront = 0,
    this.rimLight = 0,
    this.headlightBeams = 0,
    this.revealBacklight = 0,
    this.groundGlow = 0,
    this.carReveal = 0,
    this.bodyAccent = 0,
    this.grilleLights = 0,
    this.headlightsSharp = 0,
    this.interiorGlow = 0,
    this.reflection = 0,
  });

  final double shadow;
  final double stealthBacklight;
  final double fogRear;
  final double carStealth;
  final double fogFront;
  final double rimLight;
  final double headlightBeams;
  final double revealBacklight;
  final double groundGlow;
  final double carReveal;
  final double bodyAccent;
  final double grilleLights;
  final double headlightsSharp;
  final double interiorGlow;
  final double reflection;

  /// Dark parked car: body + a whisper of fog + faint red backlight, lights
  /// off. Fog kept low — at full strength its canvas-filling haze reads as a
  /// grey box against the page (device 2026-07-20).
  static const stealth = CarHeroState(
    shadow: 1,
    stealthBacklight: 0.35,
    fogRear: 0.35,
    carStealth: 1,
    fogFront: 0.25,
    rimLight: 0.35,
    reflection: 0.10,
  );

  /// Full showroom reveal: color body, lights on, glows blooming. Headlight
  /// hot-core held just under full — at 1.0 it blows out to a white blob on
  /// device (feedback 2026-07-20).
  static const reveal = CarHeroState(
    shadow: 1,
    carReveal: 1,
    revealBacklight: 1,
    groundGlow: 1,
    bodyAccent: 1,
    grilleLights: 0.9,
    headlightsSharp: 0.75,
    interiorGlow: 0.85,
    reflection: 0.28,
  );

  static CarHeroState lerp(CarHeroState a, CarHeroState b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return CarHeroState(
      shadow: l(a.shadow, b.shadow),
      stealthBacklight: l(a.stealthBacklight, b.stealthBacklight),
      fogRear: l(a.fogRear, b.fogRear),
      carStealth: l(a.carStealth, b.carStealth),
      fogFront: l(a.fogFront, b.fogFront),
      rimLight: l(a.rimLight, b.rimLight),
      headlightBeams: l(a.headlightBeams, b.headlightBeams),
      revealBacklight: l(a.revealBacklight, b.revealBacklight),
      groundGlow: l(a.groundGlow, b.groundGlow),
      carReveal: l(a.carReveal, b.carReveal),
      bodyAccent: l(a.bodyAccent, b.bodyAccent),
      grilleLights: l(a.grilleLights, b.grilleLights),
      headlightsSharp: l(a.headlightsSharp, b.headlightsSharp),
      interiorGlow: l(a.interiorGlow, b.interiorGlow),
      reflection: l(a.reflection, b.reflection),
    );
  }
}

class CarHero extends StatelessWidget {
  const CarHero({super.key, required this.state});

  final CarHeroState state;

  // Bottom-to-top compositing order (per asset-set READMEs).
  static const _layers = <(String, double Function(CarHeroState))>[
    ('stealth_backlight', _sBacklight),
    ('reveal_backlight', _rBacklight),
    ('ground_color_glow', _ground),
    ('stealth_fog_rear', _fogRear),
    ('car_shadow', _shadow),
    ('car_reflection', _reflection),
    ('car_stealth', _carStealth),
    ('car_reveal', _carReveal),
    ('body_accent_glow', _bodyAccent),
    ('stealth_fog_front', _fogFront),
    ('outline_rim_light', _rim),
    ('headlight_beams', _beams),
    ('grille_lights', _grille),
    ('headlights_sharp', _sharp),
    ('interior_glow', _interior),
  ];

  static double _sBacklight(CarHeroState s) => s.stealthBacklight;
  static double _rBacklight(CarHeroState s) => s.revealBacklight;
  static double _ground(CarHeroState s) => s.groundGlow;
  static double _fogRear(CarHeroState s) => s.fogRear;
  static double _shadow(CarHeroState s) => s.shadow;
  static double _reflection(CarHeroState s) => s.reflection;
  static double _carStealth(CarHeroState s) => s.carStealth;
  static double _carReveal(CarHeroState s) => s.carReveal;
  static double _bodyAccent(CarHeroState s) => s.bodyAccent;
  static double _fogFront(CarHeroState s) => s.fogFront;
  static double _rim(CarHeroState s) => s.rimLight;
  static double _beams(CarHeroState s) => s.headlightBeams;
  static double _grille(CarHeroState s) => s.grilleLights;
  static double _sharp(CarHeroState s) => s.headlightsSharp;
  static double _interior(CarHeroState s) => s.interiorGlow;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1536 / 1024,
      child: LayoutBuilder(
        builder: (context, c) {
          // Decode once at display resolution — full 1536px RGBA × 15 layers
          // would hold ~90MB; at card width it's a fraction of that.
          final cacheW =
              (c.maxWidth * MediaQuery.of(context).devicePixelRatio).round();
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final (name, opacityOf) in _layers)
                if (opacityOf(state) > 0.004)
                  Opacity(
                    opacity: opacityOf(state).clamp(0.0, 1.0),
                    child: Image.asset(
                      'assets/car/$name.png',
                      fit: BoxFit.contain,
                      cacheWidth: cacheW,
                      gaplessPlayback: true,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
