import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plasma_border.dart';
import 'tokens.dart';

// A premium automotive product stage: the layered card the showroom car stands
// on (spec "FoxyCo Hero Card Enhancement", 2026-07-25).
//
// Bottom-to-top: card surface, ambient spotlight, floor glow, contact shadow,
// the car. The car is passed in as HeroStage.child and is never resized or
// cropped here — this file only builds the stage around it.
//
// Everything is a FRACTION of the stage box (see HeroStageMetrics) rather than
// the spec's absolute pixels, so one composition holds from a 320 dp phone to a
// tablet.

/// Where the stage furniture sits, as fractions of the stage box.
///
/// These are tuning knobs, not derived values: the car is a fixed render, so
/// the glow has to land on ITS wheel line: not on the card's geometric bottom.
/// Nudge [groundY] on device if the pool cuts the tyres or floats under them.
///
/// 0.87 is derived from the Foxy art, not guessed: the core PNG's wheel line is
/// at 0.815 of the 1536×1024 canvas and Home shows the 0.10–0.92 band of it, so
/// (0.815 − 0.10) / 0.82 ≈ 0.87 of the stage box. Re-derive it the same way if
/// either the art or Home's crop changes.
class HeroStageMetrics {
  const HeroStageMetrics({
    this.groundY = 0.87,
    this.ringWidth = 0.82,
    this.ringHeight = 34,
    this.shadowWidth = 0.68,
    this.shadowHeight = 22,
    this.spotWidth = 1.5,
    this.spotHeight = 0.78,
    this.spotY = 0.44,
  });

  /// The wheel-contact line, 0 = top of the stage, 1 = bottom.
  final double groundY;

  /// Floor light pool: width as a fraction of the stage, height in dp.
  final double ringWidth;
  final double ringHeight;

  /// Contact shadow ellipse, same units.
  final double shadowWidth;
  final double shadowHeight;

  /// Ambient spotlight. Wider than the stage on purpose — a stretched ellipse
  /// bleeding off both edges reads as a lit room; one that fits reads as a
  /// circle drawn on a card.
  final double spotWidth;
  final double spotHeight;
  final double spotY;
}

/// Every color the stage draws with, per theme.
///
/// Light mode is the same composition at half strength (spec): the glows come
/// down 50% and the ambient turns cool so it doesn't
/// go muddy against white. The warm floor glow stays warm in both — it's the
/// thing that keeps the car from floating on paper.
class HeroStageStyle {
  const HeroStageStyle({
    required this.surface,
    required this.borderColor,
    required this.surfaceShadow,
    required this.spotlight,
    required this.ringGlow,
    required this.floorGlow,
    required this.contact,
    required this.intensity,
  });

  final Gradient surface;
  final Color borderColor;
  final List<BoxShadow> surfaceShadow;

  /// Ambient ellipse tint. Alpha is supplied by the breathing animation.
  final Color spotlight;

  final Color ringGlow;
  final Color floorGlow;
  final Color contact;

  /// Multiplies every animated glow alpha. 1.0 dark, 0.5 light.
  final double intensity;

  /// The style for the palette currently applied by [FoxColors.apply].
  factory HeroStageStyle.current() =>
      FoxColors.palette.brightness == Brightness.dark
      ? HeroStageStyle.dark()
      : HeroStageStyle.light();

  factory HeroStageStyle.dark() => HeroStageStyle(
    surface: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF13171B), Color(0xFF1C2127)],
    ),
    borderColor: Colors.white.withValues(alpha: 0.05),
    surfaceShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ],
    spotlight: Colors.white,
    ringGlow: const Color(0xFFFFB45A),
    floorGlow: const Color(0xFFFFBE78),
    contact: Colors.black.withValues(alpha: 0.55),
    intensity: 1,
  );

  factory HeroStageStyle.light() => HeroStageStyle(
    // The page's own card gradient — the stage is a card like any other here,
    // not a dark panel dropped onto paper (device 2026-07-25).
    surface: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [FoxColors.inkSoft, FoxColors.ink],
    ),
    borderColor: FoxColors.border,
    surfaceShadow: Shadows.hero,
    // Cool white: a warm ambient on white paper turns the whole card yellow.
    spotlight: const Color(0xFFDCE4EE),
    ringGlow: const Color(0xFFFF9E3D),
    floorGlow: const Color(0xFFF0E4D2),
    contact: Colors.black.withValues(alpha: 0.22),
    intensity: 0.5,
  );
}

/// The stage. [child] is drawn last, untouched, on top of everything.
///
/// One 24 s controller drives every ambient loop — 24 is the common multiple of
/// the spec's 4 s float, 4 s ring pulse, 6 s ambient breath and 8 s reflection
/// sweep, so the whole composition repeats seamlessly instead of drifting.
/// Each layer has its own [AnimatedBuilder], so a frame rebuilds four
/// `DecoratedBox`es and re-offsets one cached raster — the car itself sits
/// behind a [RepaintBoundary] and is never re-rastered by the float.
class HeroStage extends StatefulWidget {
  const HeroStage({
    super.key,
    required this.child,
    this.silhouette,
    this.metrics = const HeroStageMetrics(),
    this.borderColor,
    this.extraShadows,
    this.plasmaColor,
  });

  /// The car. Sized by its own constraints; the stage adopts its size.
  final Widget child;

  /// The car's BODY layer, laid out EXACTLY like [child] (same crop, same
  /// padding) — it is the mask for the reflection sweep, so any offset between
  /// the two shows up as a highlight sliding off the paintwork. Null disables
  /// the sweep.
  final Widget? silhouette;

  final HeroStageMetrics metrics;

  /// Overrides the style's border — the caller uses it to warm the edge when
  /// the driver is live.
  final Color? borderColor;

  /// Appended to the surface shadow (the live glow).
  final List<BoxShadow>? extraShadows;

  /// Adds the same orbiting outline used by the verdict pill. Null keeps the
  /// normal static stage border.
  final Color? plasmaColor;

  @override
  State<HeroStage> createState() => _HeroStageState();
}

class _HeroStageState extends State<HeroStage>
    with SingleTickerProviderStateMixin {
  /// The common multiple of every loop below. See the class doc.
  static const _cycle = Duration(seconds: 24);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced == _reduced && (reduced || _c.isAnimating)) return;
    _reduced = reduced;
    // ponytail: the loop runs while Home is mounted. If battery on a 10-hour
    // shift ever measures badly, gate `repeat()` on the tab being visible.
    reduced ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Position within a [seconds]-long loop, 0..1, at the master clock's value.
  double _phase(double seconds) => (_c.value * _cycle.inSeconds / seconds) % 1;

  /// A 0..1 ease-in-out-sine wave over a [seconds]-long loop.
  double _wave(double seconds) =>
      0.5 - 0.5 * math.cos(2 * math.pi * _phase(seconds));

  @override
  Widget build(BuildContext context) {
    final style = HeroStageStyle.current();
    final m = widget.metrics;
    const radius = BorderRadius.all(Radius.circular(Radii.hero));

    // Built once, outside every builder — the float re-offsets this raster, it
    // never rebuilds it.
    final car = RepaintBoundary(child: widget.child);

    final stage = DecoratedBox(
      decoration: BoxDecoration(
        gradient: style.surface,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor ?? style.borderColor),
        boxShadow: [...style.surfaceShadow, ...?widget.extraShadows],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(child: _spotlight(style, m)),
            Positioned.fill(child: _floorGlow(style, m)),
            Positioned.fill(child: _contactShadow(style, m)),
            _float(car),
            if (widget.silhouette != null)
              Positioned.fill(child: _sweep(style)),
          ],
        ),
      ),
    );
    final plasmaColor = widget.plasmaColor;
    return plasmaColor == null
        ? stage
        : PlasmaBorder(
            color: plasmaColor,
            borderRadius: Radii.hero + 3,
            child: stage,
          );
  }

  /// Huge stretched ellipse behind the car, breathing 0.08 → 0.12 over 6 s.
  Widget _spotlight(HeroStageStyle style, HeroStageMetrics m) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment(0, m.spotY * 2 - 1),
        child: FractionallySizedBox(
          widthFactor: m.spotWidth,
          heightFactor: m.spotHeight,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final a = (0.08 + 0.04 * _wave(6)) * style.intensity;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      style.spotlight.withValues(alpha: a),
                      style.spotlight.withValues(alpha: a * 0.4),
                      style.spotlight.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The lit floor under the car: a soft warm pool, no edge. It used to carry
  /// a 2 px ring border on top of this — on device that read as a hard line
  /// bisecting the card, so only the light is left (device 2026-07-26).
  /// Glow intensity cycles 0.15 → 0.35 over 4 s.
  Widget _floorGlow(HeroStageStyle style, HeroStageMetrics m) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment(0, m.groundY * 2 - 1),
        child: FractionallySizedBox(
          widthFactor: m.ringWidth,
          child: SizedBox(
            height: m.ringHeight,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final g = (0.15 + 0.20 * _wave(4)) * style.intensity;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    gradient: RadialGradient(
                      colors: [
                        style.floorGlow.withValues(
                          alpha: 0.18 * style.intensity,
                        ),
                        style.floorGlow.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.ringGlow.withValues(alpha: g),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: style.ringGlow.withValues(alpha: g * 0.5),
                        blurRadius: 70,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Dark ellipse directly under the car, between the ring and the body. It
  /// tightens as the car rises — a shadow that doesn't answer the float is what
  /// makes a floating object look pasted on.
  Widget _contactShadow(HeroStageStyle style, HeroStageMetrics m) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment(0, m.groundY * 2 - 1),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final lift = _wave(4); // 0 = car low, 1 = car high
            return FractionallySizedBox(
              widthFactor: m.shadowWidth * (1 - 0.02 * lift),
              child: SizedBox(
                height: m.shadowHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(m.shadowHeight),
                    gradient: RadialGradient(
                      colors: [
                        style.contact.withValues(
                          alpha: style.contact.a * (1 - 0.15 * lift),
                        ),
                        style.contact.withValues(alpha: 0),
                      ],
                      stops: const [0.2, 1],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ±2 px vertical drift over 4 s. Small on purpose: at 4 px it stops reading
  /// as a hovering object and starts reading as a bouncing sticker.
  Widget _float(Widget car) {
    if (_reduced) return car;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 2 - 4 * _wave(4)),
        child: child,
      ),
      child: car,
    );
  }

  /// A soft highlight crossing the body every 8 s, over 900 ms.
  ///
  /// Masked to the car's silhouette via [HeroStage.silhouette]: a screen-blended
  /// band over the whole stage would light up the empty card as well, since
  /// screen over a transparent pixel is just the band. Built ONLY inside the
  /// 900 ms window, so it costs nothing the other 89% of the loop.
  Widget _sweep(HeroStageStyle style) {
    const window = 0.9 / 8; // 900 ms of the 8 s loop
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_reduced) return const SizedBox.shrink();
          final p = _phase(8);
          if (p > window) return const SizedBox.shrink();
          final t = p / window; // 0..1 across the body
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.transparent,
              ],
              stops: [
                (t * 1.6 - 0.30).clamp(0.0, 1.0),
                (t * 1.6 - 0.15).clamp(0.0, 1.0),
                (t * 1.6).clamp(0.0, 1.0),
              ],
            ).createShader(r),
            // The body layer painted flat white = the car's silhouette.
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcATop,
              ),
              child: Opacity(opacity: 0.08, child: widget.silhouette),
            ),
          );
        },
      ),
    );
  }
}
