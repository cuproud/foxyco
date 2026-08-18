import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/car_hero.dart';
import '../theme/tokens.dart';

/// Cold-start splash (spec M6 §10, Foxy brand art 2026-07-26). A single
/// [AnimationController] drives a two-act ignition over 2.2s: car and logo
/// fade up together from black (0–0.30), then the glow flares on with a
/// cold-start flicker (0.30–0.80). A hard 3.5s ceiling [Timer]
/// force-navigates even if the controller stalls — the splash never traps.
/// Reduced motion skips the animation: car, glow and logo show instantly and a
/// short timer moves on.
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

  /// Glow flicker: two brief dips on the way to full, like a cold start.
  static double _flicker(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (t < 0.35) return t * 2.0; // first surge
    if (t < 0.45) return 0.15; // dip
    if (t < 0.70) return 0.9; // second surge
    if (t < 0.78) return 0.4; // dip
    return 1.0; // steady on
  }

  static double _fadeAt(double t) =>
      const Interval(0, 0.30, curve: Curves.easeOut).transform(t);

  static double _glowAt(double t) =>
      _flicker(const Interval(0.30, 0.80).transform(t));

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: FoxColors.bgBase,
      body: reduced
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SplashCar(
                    fade: 1,
                    glow: 1,
                    onDark: FoxColors.palette.brightness == Brightness.dark,
                  ),
                  SizedBox(height: Gap.lg),
                  _Wordmark(opacity: 1),
                ],
              ),
            )
          : AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                // Car and wordmark share ONE fade: staggering the logo late
                // (it used to start at 0.65) left it on screen for a blink
                // before the route swap (device 2026-07-26).
                final fade = _fadeAt(t);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SplashCar(
                        fade: fade,
                        glow: _glowAt(t),
                        onDark: FoxColors.palette.brightness == Brightness.dark,
                      ),
                      const SizedBox(height: Gap.lg),
                      _Wordmark(opacity: fade),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Car capped to a phone-friendly width so the splash column never overflows
/// short viewports. [fade] is the whole car rising out of black — one Opacity
/// over both layers, which only the splash pays for.
class _SplashCar extends StatelessWidget {
  const _SplashCar({
    required this.fade,
    required this.glow,
    required this.onDark,
  });

  final double fade;
  final double glow;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final w = math.min(360.0, MediaQuery.of(context).size.width * 0.86);
    return SizedBox(
      width: w,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: CarHero(glow: glow, onDark: onDark),
      ),
    );
  }
}

/// The gold FoxyCo wordmark (`logo 3d`), the brand's main logo since 2026-07-26.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Image.asset(
        'assets/branding/foxyco_logo.png',
        key: const Key('splash-wordmark'),
        width: 220,
        semanticLabel: 'FoxyCo',
      ),
    );
  }
}
