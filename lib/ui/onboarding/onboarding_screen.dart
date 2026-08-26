import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/thresholds.dart';
import '../../services/accessibility/accessibility_watcher.dart';
import '../home/dashboard_controller.dart';
import '../legal/accessibility_disclosure.dart';
import '../legal/legal_links.dart';
import '../overlay/overlay_controller.dart';
import '../settings/garage_controller.dart';
import '../settings/settings_controller.dart';
import '../theme/tokens.dart';
import 'onboarding_gate.dart';

/// First-run walkthrough that explains the two sensitive permissions before
/// requesting them.
///
/// Five swipeable pages: meet FoxyCo → pick a threshold preset → understand
/// the trial/lifetime unlock → overlay grant → accessibility grant. The preset
/// page personalizes BEFORE the
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

  static const pageCount = 5;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
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

  /// Both exits (CTA and skip) land here, so the name is saved whichever way
  /// the driver leaves — once, on the way out, rather than a prefs write per
  /// keystroke.
  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      await ref.read(driverNameProvider.notifier).setName(name);
    }
    // Awaited: the write used to race the navigation, so a process death in
    // that window replayed the whole wizard on next launch.
    await OnboardingGate.markDone();
    if (mounted) context.go('/');
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
    final cta = _page == 3 && !perms.overlayGranted
        ? 'Allow display over apps'
        : _page == 4 && !perms.accessibilityGranted
        ? 'Enable offer access'
        : !last
        ? 'Next'
        : 'Finish setup';
    final permissionPage =
        (_page == 3 && !perms.overlayGranted) ||
        (_page == 4 && !perms.accessibilityGranted);

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
                  _Page(
                    hero: const _FoxHero(),
                    title: 'Meet FoxyCo',
                    body:
                        'FoxyCo reads each offer and scores it GOOD, OK or BAD '
                        'using your chosen \$/km or \$/hr rules. You decide; '
                        'accepting or declining stays your tap.',
                    // Asked here, on the introductions page. Without it the
                    // greeting on Home never appears — ProfileCard hides itself
                    // on an empty name, so first-run Home had no greeting at
                    // all until the driver found Settings → Garage.
                    footer: _NameField(controller: _name),
                  ),
                  const _Page(
                    hero: _GlowIcon(Icons.tune_rounded),
                    title: 'Set your bar',
                    body:
                        'Choose whether FoxyCo scores by distance or time, then '
                        'set your GOOD and BAD limits. Minimum Offer marks very '
                        'small payouts BAD. Pickup Guard highlights long '
                        'pickups. Voice Verdict can read the result aloud.',
                    footer: _PresetPicker(),
                  ),
                  const _Page(
                    hero: _ArtHero('assets/branding/foxyco_head.png'),
                    title: 'Try a week. Pay once.',
                    body:
                        'Use every feature free for 7 days. After the trial, '
                        'one Google Play purchase unlocks FoxyCo for life. '
                        'There is no subscription or recurring fee.',
                    footer: _BillingPromise(),
                  ),
                  _GrantPage(
                    hero: const _GlowIcon(Icons.picture_in_picture_alt_rounded),
                    title: 'Display over other apps',
                    body:
                        'FoxyCo floats the verdict pill over your watched gig apps '
                        'so you can read it without switching apps.',
                    granted: perms.overlayGranted,
                  ),
                  _GrantPage(
                    hero: const _GlowIcon(Icons.visibility_rounded),
                    title: 'Offer access',
                    body: accessibilityDisclosureBody,
                    granted: perms.accessibilityGranted,
                  ),
                ],
              ),
            ),
            _Dots(page: _page),
            const SizedBox(height: Gap.sm),
            // Click-wrap: assent is given by continuing, so it sits with the
            // button that continues — not buried in Settings (AUDIT legal).
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Gap.md),
              child: LegalConsent(),
            ),
            const SizedBox(height: Gap.sm),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: permissionPage
                    ? OutlinedButton(
                        onPressed: _page == 3
                            ? _grantOverlay
                            : _grantAccessibility,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FoxColors.brandFox,
                          side: const BorderSide(color: FoxColors.brandFox),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.card),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(cta),
                      )
                    : FilledButton(
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
            // Not on the last page: the CTA there is already "Finish without
            // access", so a skip link under it is the same button twice.
            if (!last || permissionPage)
              TextButton(
                onPressed: _finish,
                child: Text(
                  permissionPage && _page == 4
                      ? 'Finish setup without it'
                      : 'Skip for now',
                  style: TextStyle(color: FoxColors.textSecondary),
                ),
              )
            else
              const SizedBox(height: 48), // hold the CTA's position steady
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
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/foxyco_head.png',
    width: 96,
    height: 96,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

class _ArtHero extends StatelessWidget {
  const _ArtHero(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) => Container(
    width: 132,
    height: 132,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radii.hero),
      boxShadow: Shadows.hero,
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(asset, fit: BoxFit.cover),
  );
}

class _BillingPromise extends StatelessWidget {
  const _BillingPromise();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
    decoration: BoxDecoration(
      color: FoxColors.brandFoxSoft,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(color: FoxColors.brandFox.withValues(alpha: 0.28)),
    ),
    child: const Row(
      children: [
        Icon(Icons.all_inclusive_rounded, size: 17, color: FoxColors.brandFox),
        SizedBox(width: Gap.sm),
        Flexible(
          child: Text(
            'Lifetime unlock · no recurring fees',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
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
    final settings = ref.watch(settingsProvider);
    final current = settings.thresholds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, t) in Thresholds.presets) ...[
          _PresetCard(
            label: label,
            sub:
                'GOOD from ${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(t.goodAtOrAbove).toStringAsFixed(2)}/${settings.distanceUnit.shortLabel}',
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      // Page token: this card is bgSurface/bgSurface2, not a
                      // gradient card.
                      color: FoxColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
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
  });

  final Widget hero;
  final String title;
  final String body;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return _Page(
      hero: hero,
      title: title,
      body: body,
      footer: granted
          // liveRegion: the chip replaces the grant button when the driver
          // comes back from system settings. Sighted users see the swap; a
          // screen-reader user got no confirmation at all that the grant they
          // just made landed — on the accessibility page, of all places.
          ? Semantics(
              liveRegion: true,
              label: '$title granted',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                decoration: BoxDecoration(
                  color: VerdictColors.goodBg,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '✅ Granted',
                  style: TextStyle(
                    color: VerdictColors.good,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Page dots — active dot stretches into a 20px orange pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    // Decorative: to a screen reader these are unlabeled boxes between
    // the page body and the CTA. Position is announced by the PageView itself.
    return ExcludeSemantics(
      child: Row(
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
      ),
    );
  }
}

/// Optional "what should I call you?" field on the intro page.
///
/// Optional on purpose — a required field on page 1 of a first run is a wall.
/// The value is read once by [_OnboardingScreenState._finish]; the controller
/// lives up there so it survives page swipes.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: 24,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FoxColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '', // the 24-cap is a guard, not a target
          labelText: 'What should I call you?',
          hintText: 'Your name (optional)',
          filled: true,
          fillColor: FoxColors.bgSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.field),
            borderSide: BorderSide(color: FoxColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.field),
            borderSide: BorderSide(color: FoxColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.field),
            borderSide: const BorderSide(color: FoxColors.brandFox),
          ),
        ),
      ),
    );
  }
}
