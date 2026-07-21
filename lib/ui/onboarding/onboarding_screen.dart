import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/thresholds.dart';
import '../../services/accessibility/accessibility_watcher.dart';
import '../home/dashboard_controller.dart';
import '../overlay/overlay_controller.dart';
import '../settings/settings_controller.dart';
import '../theme/tokens.dart';
import 'onboarding_gate.dart';

/// First-run walkthrough (UI_DESIGN §5.1) — earns the two scary permissions
/// honestly, per Play accessibility policy (AUDIT #1/#2).
///
/// Four swipeable pages: meet FoxyCo → pick a threshold preset → overlay
/// grant → accessibility grant. The preset page personalizes BEFORE the
/// permission asks, so the driver has seen value first.
///
/// The accessibility page carries the full plain-language disclosure: FoxyCo
/// only READS pay + distance from offer screens to score them — nothing is
/// sent anywhere and it never taps buttons or acts inside any app (the
/// strictly-manual product rule). Each grant page flips to a ✅ once granted;
/// "Skip for now" always works — the app runs, it just can't watch yet.
///
/// Grant state comes from [dashboardProvider.permissions]: `main.dart` already
/// re-runs [DashboardController.refreshPermissions] on every app resume, so
/// returning from the system settings trip updates the page by itself.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const pageCount = 4;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < OnboardingScreen.pageCount - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    OnboardingGate.markDone();
    context.go('/');
  }

  Future<void> _grantOverlay() async {
    await ref.read(overlayServiceProvider).requestPermission();
    await ref.read(dashboardProvider.notifier).refreshPermissions();
  }

  Future<void> _grantAccessibility() async {
    await ref.read(accessibilityWatcherProvider).requestPermission();
    await ref.read(dashboardProvider.notifier).refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(dashboardProvider.select((s) => s.permissions));
    final last = _page == OnboardingScreen.pageCount - 1;
    // Honest CTA: finishing without the key grant lands on a blocked Home —
    // say so instead of promising "smarter driving".
    final cta = !last
        ? 'Next'
        : perms.accessibilityGranted
        ? 'Start driving smarter'
        : 'Finish without access';

    return Scaffold(
      backgroundColor: FoxColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _Page(
                    hero: _FoxHero(),
                    title: 'Meet FoxyCo 🍪',
                    body:
                        'Your co-driver that reads every ride offer and tells '
                        'you GOOD / OK / BAD in a glance — so you decide '
                        'faster and only chase the tasty ones. FoxyCo only '
                        'advises; accepting or declining is always your tap, '
                        'in the driver app.',
                  ),
                  const _Page(
                    hero: _GlowIcon(Icons.tune_rounded),
                    title: 'Set your bar',
                    body:
                        'Where does a GOOD offer start for you? Pick a starting '
                        'point — every number stays tunable in Settings.',
                    footer: _PresetPicker(),
                  ),
                  _GrantPage(
                    hero: const _GlowIcon(Icons.picture_in_picture_alt_rounded),
                    title: 'Draw over other apps',
                    body:
                        'FoxyCo floats a tiny verdict pill over Uber, Lyft and '
                        'Hopp so you never have to switch apps mid-offer.',
                    granted: perms.overlayGranted,
                    buttonLabel: 'Grant “Display over other apps”',
                    onGrant: _grantOverlay,
                  ),
                  _GrantPage(
                    hero: const _GlowIcon(Icons.visibility_rounded),
                    title: 'Read the offer on screen',
                    body:
                        'FoxyCo uses Android\'s accessibility service ONLY to '
                        'read an offer\'s pay and distance on screen, to score '
                        'it for you. It does not read anything else, sends '
                        'nothing off your phone, and never taps buttons or '
                        'accepts/declines rides for you.',
                    granted: perms.accessibilityGranted,
                    buttonLabel: 'Grant Accessibility Access',
                    onGrant: _grantAccessibility,
                  ),
                ],
              ),
            ),
            _Dots(page: _page),
            const SizedBox(height: Gap.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: FoxColors.brandFox,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(cta),
                ),
              ),
            ),
            TextButton(
              onPressed: _finish,
              child: const Text(
                'Skip for now',
                style: TextStyle(color: FoxColors.textSecondary),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

/// Fox head hero for the intro page.
class _FoxHero extends StatelessWidget {
  const _FoxHero();

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/branding/foxyco_head.png', width: 96, height: 96);
}

/// Icon in a glowing orange disc — replaces the emoji heroes, which read
/// cheap next to the fox mark + Fraunces (premium pass 2026-07-20).
class _GlowIcon extends StatelessWidget {
  const _GlowIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: FoxColors.brandFoxSoft,
        shape: BoxShape.circle,
        border: Border.all(color: FoxColors.brandFox.withValues(alpha: 0.35)),
        boxShadow: Shadows.glowSoft,
      ),
      child: Icon(icon, size: 44, color: FoxColors.brandFox),
    );
  }
}

/// Threshold preset chips (Relaxed / Balanced / Picky) — applies straight to
/// [settingsProvider] so the pick IS the setting, no extra save.
class _PresetPicker extends ConsumerWidget {
  const _PresetPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider).thresholds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, t) in Thresholds.presets) ...[
          _PresetCard(
            label: label,
            sub: 'GOOD from \$${t.goodAtOrAbove.toStringAsFixed(2)}/km',
            selected: current == t,
            onTap: () => ref.read(settingsProvider.notifier).applyPreset(t),
          ),
          if ((label, t) != Thresholds.presets.last)
            const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.cardSm),
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? FoxColors.bgSurface2 : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(
            color: selected ? FoxColors.brandFox : FoxColors.borderSoft,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? Shadows.glowSoft : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FoxColors.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FoxColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: FoxColors.brandFox,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Intro page: hero mark, headline, body, optional footer (grant button /
/// chip / preset picker).
class _Page extends StatelessWidget {
  const _Page({
    required this.hero,
    required this.title,
    required this.body,
    this.footer,
  });

  final Widget hero;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Scrollable: preset page + small phones + large font scale would
    // overflow a fixed Column.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: Gap.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            hero,
            const SizedBox(height: Gap.lg),
            Text(
              title,
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.md),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: FoxColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: Gap.lg), footer!],
          ],
        ),
      ),
    );
  }
}

/// A [_Page] whose footer is the grant button, flipping to a green ✅ chip once
/// the permission is actually held (state re-checked on app resume).
class _GrantPage extends StatelessWidget {
  const _GrantPage({
    required this.hero,
    required this.title,
    required this.body,
    required this.granted,
    required this.buttonLabel,
    required this.onGrant,
  });

  final Widget hero;
  final String title;
  final String body;
  final bool granted;
  final String buttonLabel;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return _Page(
      hero: hero,
      title: title,
      body: body,
      footer: granted
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              decoration: BoxDecoration(
                color: VerdictColors.goodBg,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: const Text(
                '✅ Granted',
                style: TextStyle(
                  color: VerdictColors.good,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onGrant,
              style: OutlinedButton.styleFrom(
                foregroundColor: FoxColors.brandFox,
                side: const BorderSide(color: FoxColors.brandFox),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(buttonLabel),
            ),
    );
  }
}

/// Page dots — active dot stretches into a 20px orange pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < OnboardingScreen.pageCount; i++)
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            width: i == page ? 20 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              color: i == page ? FoxColors.brandFox : FoxColors.border,
            ),
          ),
      ],
    );
  }
}
