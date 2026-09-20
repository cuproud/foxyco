import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scenic cold-start splash based on the seasonal FoxyCo welcome artwork.
/// A hard ceiling still guarantees that startup can never strand the user.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

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
      duration: const Duration(milliseconds: 2500),
    );
    _ceiling = Timer(const Duration(milliseconds: 3500), _go);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _reducedTimer = Timer(const Duration(milliseconds: 500), _go);
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
    for (final asset in const [
      'assets/branding/foxy_splash_car.webp',
      'assets/branding/foxyco_logo.png',
    ]) {
      precacheImage(AssetImage(asset), context);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEE4),
      body: reduced
          ? const _SplashScene(progress: 1)
          : AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => _SplashScene(progress: _controller.value),
            ),
    );
  }
}

enum _SplashSeason {
  mountains,
  snow,
  autumn;

  String get label => switch (this) {
    mountains => 'mountain',
    snow => 'winter',
    autumn => 'autumn',
  };
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final season = switch (progress) {
      < 1 / 3 => _SplashSeason.mountains,
      < 2 / 3 => _SplashSeason.snow,
      _ => _SplashSeason.autumn,
    };
    return Semantics(
      container: true,
      label: 'FoxyCo ${season.label} welcome scene',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final carWidth = math.min(430.0, size.width * 0.98);
          final entrance = Curves.easeOutCubic.transform(
            const Interval(0, 0.72).transform(progress),
          );
          final brand = Curves.easeOut.transform(
            const Interval(0.52, 0.92).transform(progress),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _SeasonPainter(
                    season: season,
                    progress: progress,
                    entrance: entrance,
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.27,
                left: (size.width - carWidth) / 2,
                width: carWidth,
                child: Transform.translate(
                  offset: Offset((1 - entrance) * size.width * 1.15, 0),
                  child: Image.asset(
                    'assets/branding/foxy_splash_car.webp',
                    key: const Key('splash-car'),
                    semanticLabel: 'Fox driving a black sports car',
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.64,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, (1 - brand) * 8),
                  child: Opacity(
                    opacity: brand,
                    child: Center(
                      child: SizedBox(
                        width: math.min(250.0, size.width * 0.69),
                        child: Stack(
                          children: [
                            Image.asset(
                              'assets/branding/foxyco_logo.png',
                              key: const Key('splash-wordmark'),
                              semanticLabel: 'FoxyCo',
                            ),
                            Positioned(
                              right: 9,
                              top: 43,
                              child: Transform.rotate(
                                angle: progress * math.pi * 4,
                                child: const _WheelLoader(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.84,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: brand,
                  child: const Text(
                    'Your drive. Your rules.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF5E5044),
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WheelLoader extends StatelessWidget {
  const _WheelLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('splash-loader'),
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE99526), width: 2),
        gradient: const SweepGradient(
          colors: [Colors.transparent, Color(0xFFFFCF72), Color(0xFFE99526)],
          stops: [0.45, 0.78, 1],
        ),
      ),
    );
  }
}

class _SeasonPainter extends CustomPainter {
  const _SeasonPainter({
    required this.season,
    required this.progress,
    required this.entrance,
  });

  final _SplashSeason season;
  final double progress;
  final double entrance;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 660);
    _paintLandscape(canvas);
    _paintWeather(canvas);
    _paintSmoke(canvas);
    _paintBushes(canvas);
    canvas.restore();
  }

  void _paintLandscape(Canvas canvas) {
    final colors = switch (season) {
      _SplashSeason.mountains => const [
        Color(0xFFD9E7E5),
        Color(0xFFEDF0DF),
        Color(0xFFB8CAC6),
        Color(0xFF90A8A2),
        Color(0xFF647F78),
        Color(0xFFF2EEE4),
      ],
      _SplashSeason.snow => const [
        Color(0xFFCBDDE9),
        Color(0xFFF0F6F8),
        Color(0xFFC0D1DE),
        Color(0xFFA3BACB),
        Color(0xFF7E9EAF),
        Color(0xFFF5F5EF),
      ],
      _SplashSeason.autumn => const [
        Color(0xFFF2DDBE),
        Color(0xFFFFF0D6),
        Color(0xFFD4BEA3),
        Color(0xFFB9A88E),
        Color(0xFF8E8C71),
        Color(0xFFF4EAD9),
      ],
    };
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 660),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: const Alignment(0, 0.35),
          colors: colors.take(2).toList(),
        ).createShader(const Rect.fromLTWH(0, 0, 360, 420)),
    );
    canvas.drawCircle(
      const Offset(270, 98),
      28,
      Paint()..color = const Color(0xCCFFF4C5),
    );
    _mountain(canvas, colors[2], const [
      Offset(0, 236),
      Offset(0, 192),
      Offset(48, 143),
      Offset(84, 173),
      Offset(155, 83),
      Offset(202, 152),
      Offset(234, 125),
      Offset(302, 193),
      Offset(338, 158),
      Offset(360, 181),
      Offset(360, 295),
    ]);
    _mountain(canvas, colors[3], const [
      Offset(0, 300),
      Offset(0, 245),
      Offset(56, 206),
      Offset(105, 227),
      Offset(186, 146),
      Offset(250, 210),
      Offset(286, 181),
      Offset(360, 243),
      Offset(360, 322),
    ]);
    _mountain(canvas, colors[4], const [
      Offset(0, 360),
      Offset(0, 263),
      Offset(38, 245),
      Offset(83, 276),
      Offset(136, 254),
      Offset(195, 286),
      Offset(259, 231),
      Offset(309, 270),
      Offset(360, 238),
      Offset(360, 360),
    ]);
    canvas.drawRect(
      const Rect.fromLTWH(0, 270, 360, 390),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[5].withValues(alpha: 0), colors[5]],
          stops: const [0, 0.38],
        ).createShader(const Rect.fromLTWH(0, 270, 360, 390)),
    );
  }

  void _mountain(Canvas canvas, Color color, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintWeather(Canvas canvas) {
    final paint = Paint()..strokeWidth = 1;
    final count = season == _SplashSeason.autumn ? 14 : 42;
    for (var i = 0; i < count; i++) {
      final x = ((i * 71 + 31 + progress * 28) % 400) - 20;
      final y = ((i * 43 + 19 + progress * 160) % 500) - 20;
      switch (season) {
        case _SplashSeason.snow:
          paint.color = Colors.white.withValues(alpha: 0.45 + (i % 4) * 0.1);
          canvas.drawCircle(Offset(x, y), 1 + (i % 3) * 0.45, paint);
        case _SplashSeason.autumn:
          paint.color = [
            const Color(0xFFB97836),
            const Color(0xFFC98639),
            const Color(0xFFAF6541),
          ][i % 3].withValues(alpha: 0.65);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(i * 0.7 + progress * 2);
          canvas.drawOval(const Rect.fromLTWH(-3, -1.5, 6, 3), paint);
          canvas.restore();
        case _SplashSeason.mountains:
          paint.color = const Color(0x44658A9C);
          canvas.drawLine(Offset(x, y), Offset(x - 3, y - 10), paint);
      }
    }
  }

  void _paintSmoke(Canvas canvas) {
    if (progress < 0.12 || progress > 0.92) return;
    final local = ((progress - 0.12) / 0.8).clamp(0.0, 1.0);
    final carX = (1 - entrance) * 414;
    for (var i = 0; i < 9; i++) {
      final phase = (local - i * 0.045).clamp(0.0, 1.0);
      if (phase == 0) continue;
      final alpha = math.sin(phase * math.pi) * 0.24;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(326 + carX + phase * 34, 368 - phase * (18 + i)),
          width: 24 + phase * 58,
          height: 14 + phase * 38,
        ),
        Paint()..color = const Color(0xFF746D64).withValues(alpha: alpha),
      );
    }
  }

  void _paintBushes(Canvas canvas) {
    final colors = switch (season) {
      _SplashSeason.mountains => const [
        Color(0xFF758571),
        Color(0xFF90A17F),
        Color(0xFFB3BA96),
      ],
      _SplashSeason.snow => const [
        Color(0xFF849C99),
        Color(0xFFA5B7B0),
        Color(0xFFF7FAF4),
      ],
      _SplashSeason.autumn => const [
        Color(0xFF846647),
        Color(0xFFBC783A),
        Color(0xFFE2B157),
      ],
    };
    for (final side in [-1.0, 1.0]) {
      final edge = side < 0 ? 0.0 : 360.0;
      for (var i = 0; i < 18; i++) {
        final spread = (i % 6) * 13.0;
        final x = edge - side * spread + math.sin(i * 2.7) * 8;
        final y = 570 + (i % 5) * 20.0;
        final radius = 15.0 + (i % 4) * 5;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: radius * 1.8,
            height: radius * 1.35,
          ),
          Paint()..color = colors[i % colors.length],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SeasonPainter oldDelegate) =>
      oldDelegate.season != season || oldDelegate.progress != progress;
}
