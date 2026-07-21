import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/garage_controller.dart';
import '../theme/tokens.dart';

/// Open greeting above the showroom car: one compact serif line straight on
/// the page — no card, no box, no vehicle details (device feedback
/// 2026-07-20). Hidden until the driver gives a name.
/// One-shot fade+slide entrance, skipped under reduced motion.
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

  /// Food emoji per band, appended after the name — the fox eats around the
  /// clock ("Good evening, Vamsi 🍜").
  static String snackFor(int hour) {
    if (hour >= 5 && hour < 12) return '☕';
    if (hour >= 12 && hour < 17) return '🌮';
    if (hour >= 17 && hour < 22) return '🍜';
    return '🍪';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(driverNameProvider).trim();
    if (name.isEmpty) return const SizedBox.shrink();

    final greeting = Text.rich(
      TextSpan(
        text: '${greetingFor(DateTime.now().hour)}, ',
        children: [
          TextSpan(
            text: name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: FoxColors.brandFox,
            ),
          ),
          TextSpan(text: ' ${snackFor(DateTime.now().hour)}'),
        ],
      ),
      // Long names wrap to a second line instead of clipping.
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: FoxFonts.sans,
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: FoxColors.creamDim,
      ),
    );

    // Bottom padding lives INSIDE this widget so the home list only gains
    // spacing when the greeting actually shows (shrink stays truly zero).
    if (MediaQuery.of(context).disableAnimations) {
      return Padding(
        padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
        child: greeting,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
      child: _AnimatedEntrance(child: greeting),
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
  late final _slide = Tween(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_fade);

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
