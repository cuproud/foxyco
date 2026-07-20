import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/car_hero.dart';
import '../theme/tokens.dart';

/// Cold-start splash (spec M6 §10, car-hero redesign 2026-07-20). A single
/// [AnimationController] drives a three-act ignition sequence over 2.2s:
/// stealth car fades from black (0–0.27), lights flare on with a flicker
/// (0.27–0.55), then the full-color reveal blooms and the wordmark fades up
/// (0.55–1.0). A hard 3.5s ceiling [Timer] force-navigates even if the
/// controller stalls — the splash never traps. Reduced motion skips the
/// animation: the full reveal + wordmark show instantly and a short timer
/// moves on.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _ceiling;
  Timer? _reducedTimer;
  bool _navigated = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    // Ceiling armed before anything can fail — splash always exits.
    _ceiling = Timer(const Duration(milliseconds: 3500), _go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = MediaQuery.of(context).disableAnimations;
      if (reduced) {
        _reducedTimer = Timer(const Duration(milliseconds: 500), _go);
      } else {
        _c.forward().whenComplete(_go);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Warm every car layer at HOME's full-bleed decode width — the splash
    // decodes its own (smaller) copies on first frame regardless; this makes
    // the Home hero appear instantly after navigation, no layer pop-in.
    final mq = MediaQuery.of(context);
    final cacheW = (mq.size.width * mq.devicePixelRatio).round();
    for (final name in CarHero.layerNames) {
      precacheImage(
        ResizeImage(AssetImage('assets/car/$name.png'), width: cacheW),
        context,
      );
    }
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
    _reducedTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Headlight flicker: two brief dips on the way to full, like a cold start.
  static double _flicker(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (t < 0.35) return t * 2.0; // first surge
    if (t < 0.45) return 0.15; // dip
    if (t < 0.70) return 0.9; // second surge
    if (t < 0.78) return 0.4; // dip
    return 1.0; // steady on
  }

  CarHeroState _stateAt(double t) {
    final fadeIn = const Interval(0.0, 0.27, curve: Curves.easeOut)
        .transform(t);
    final ignition = const Interval(0.27, 0.55).transform(t);
    final reveal = const Interval(0.55, 1.0, curve: Curves.easeInOutCubic)
        .transform(t);
    final lights = _flicker(ignition);

    // Stealth base fades in, then the reveal crossfade takes over.
    final base = CarHeroState.lerp(
      const CarHeroState(),
      CarHeroState.stealth,
      fadeIn,
    );
    final lit = CarHeroState(
      shadow: base.shadow,
      stealthBacklight: base.stealthBacklight,
      fogRear: base.fogRear,
      carStealth: base.carStealth,
      fogFront: base.fogFront,
      rimLight: (base.rimLight + 0.65 * lights).clamp(0.0, 1.0),
      headlightBeams: lights,
      headlightsSharp: lights,
      grilleLights: lights,
      interiorGlow: 0.8 * lights,
      reflection: base.reflection,
    );
    return CarHeroState.lerp(lit, CarHeroState.reveal, reveal);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: FoxColors.bgBase,
      body: reduced
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SplashCar(state: CarHeroState.reveal),
                  SizedBox(height: Gap.lg),
                  _Wordmark(opacity: 1),
                ],
              ),
            )
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final wordmark = const Interval(
                  0.65,
                  0.95,
                  curve: Curves.easeOut,
                ).transform(t);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SplashCar(state: _stateAt(t)),
                      const SizedBox(height: Gap.lg),
                      _Wordmark(opacity: wordmark),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Car capped to a phone-friendly width so the splash column never overflows
/// short viewports.
class _SplashCar extends StatelessWidget {
  const _SplashCar({required this.state});

  final CarHeroState state;

  @override
  Widget build(BuildContext context) {
    final w = math.min(360.0, MediaQuery.of(context).size.width * 0.86);
    return SizedBox(width: w, child: CarHero(state: state));
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
