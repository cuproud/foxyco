import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Premium FoxyCo cold-start splash.
///
/// Uses one finished full-screen key-art image instead of rebuilding the
/// mountains, car, logo, and weather as independent runtime layers.
///
/// Runtime motion is intentionally restrained:
/// - subtle 2.5% camera push-in
/// - tiny upward drift
/// - one soft light sweep across the baked-in FoxyCo logo
/// - ~1.8 second total duration
///
/// A hard ceiling still guarantees that startup can never strand the user.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const _heroAsset = 'assets/branding/foxyco_golden_mountain_drive.png';
const _artSize = Size(863, 1822);

BoxFit _artFit(Size size) =>
    size.aspectRatio > .70 ? BoxFit.contain : BoxFit.cover;

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _ceiling;
  Timer? _reducedTimer;
  bool _navigated = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Safety fallback only. Normal navigation happens when the animation ends.
    _ceiling = Timer(const Duration(milliseconds: 2600), _go);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (MediaQuery.of(context).disableAnimations) {
        _reducedTimer = Timer(const Duration(milliseconds: 450), _go);
      } else {
        _controller.forward().whenComplete(_go);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    precacheImage(const AssetImage(_heroAsset), context);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D2227),
        body: reduced
            ? const _PremiumSplashScene(
                progress: 1,
                reduced: true,
                artwork: _SplashArtwork(),
              )
            : AnimatedBuilder(
                animation: _controller,
                child: const _SplashArtwork(),
                builder: (_, child) => _PremiumSplashScene(
                  progress: _controller.value,
                  artwork: child!,
                ),
              ),
      ),
    );
  }
}

class _PremiumSplashScene extends StatelessWidget {
  const _PremiumSplashScene({
    required this.progress,
    required this.artwork,
    this.reduced = false,
  });

  final double progress;
  final Widget artwork;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final camera = reduced
        ? 0.0
        : Curves.easeOutCubic.transform(
            const Interval(0.00, 0.90).transform(progress),
          );

    // Barely perceptible initial fade prevents a harsh first-frame pop.
    final reveal = Curves.easeOut.transform(
      const Interval(0.00, 0.22).transform(progress),
    );

    // Sweep is visible only for a short middle window.
    final sweep = Curves.easeInOutCubic.transform(
      const Interval(0.42, 0.74).transform(progress),
    );

    return Semantics(
      container: true,
      label: 'FoxyCo welcome',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final fit = _artFit(size);
          final widthScale = size.width / _artSize.width;
          final heightScale = size.height / _artSize.height;
          final artScale = fit == BoxFit.cover
              ? math.max(widthScale, heightScale)
              : math.min(widthScale, heightScale);
          final artWidth = _artSize.width * artScale * (1 + .025 * camera);
          final artHeight = _artSize.height * artScale * (1 + .025 * camera);
          final logoRect = Rect.fromLTWH(
            (size.width - artWidth) / 2 + artWidth * .13,
            (size.height - artHeight) / 2 - 5 * camera + artHeight * .60,
            artWidth * .75,
            artHeight * .19,
          );

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: Opacity(
                    opacity: 0.94 + (0.06 * reveal),
                    child: Transform.translate(
                      offset: Offset(0, -5 * camera),
                      child: Transform.scale(
                        // Slow cinematic push-in; small enough to preserve
                        // the safe area around the baked-in logo/tagline.
                        scale: 1 + (0.025 * camera),
                        alignment: Alignment.center,
                        child: artwork,
                      ),
                    ),
                  ),
                ),

                // Gentle edge treatment keeps the screen pleasant and prevents
                // the bright sunset from feeling harsh on high-brightness phones.
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.08),
                        radius: 1.15,
                        colors: [
                          Colors.transparent,
                          Color(0x05000000),
                          Color(0x16000000),
                        ],
                        stops: [0.52, 0.78, 1],
                      ),
                    ),
                  ),
                ),

                // One restrained glint over the lower-middle logo zone.
                if (!reduced && progress >= 0.42 && progress <= 0.78)
                  Positioned(
                    key: const Key('splash-glint'),
                    left: logoRect.left,
                    top: logoRect.top,
                    width: logoRect.width,
                    height: logoRect.height,
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset(
                          (-logoRect.width * .2) +
                              (logoRect.width * 1.4 * sweep),
                          0,
                        ),
                        child: Transform.rotate(
                          angle: -0.20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: logoRect.width * .14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.13),
                                    Colors.white.withValues(alpha: 0.30),
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0, 0.28, 0.50, 0.72, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kept as AnimatedBuilder's child: decoding/layout does not repeat each tick.
class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) => Image.asset(
        _heroAsset,
        key: const Key('splash-key-art'),
        semanticLabel:
            'FoxyCo. Your drive. Your rules. Fox driving a black sports car through a golden mountain landscape.',
        fit: _artFit(constraints.biggest),
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}
