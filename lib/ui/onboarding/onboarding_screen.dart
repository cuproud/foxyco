import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/accessibility/accessibility_watcher.dart';
import '../home/dashboard_controller.dart';
import '../overlay/overlay_controller.dart';
import '../theme/tokens.dart';
import 'onboarding_gate.dart';

/// First-run walkthrough (UI_DESIGN §5.1) — earns the two scary permissions
/// honestly, per Play accessibility policy (AUDIT #1/#2).
///
/// Three swipeable pages: meet FoxyCo → overlay grant → accessibility grant.
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
    if (_page < 2) {
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
                    emoji: '🦊',
                    title: 'Meet FoxyCo',
                    body:
                        'Your co-driver that reads every ride offer and tells '
                        'you GOOD / OK / BAD in a glance — so you decide '
                        'faster. FoxyCo only advises; accepting or declining '
                        'is always your tap, in the driver app.',
                  ),
                  _GrantPage(
                    emoji: '🫧',
                    title: 'Draw over other apps',
                    body:
                        'FoxyCo floats a tiny verdict pill over Uber, Lyft and '
                        'Hopp so you never have to switch apps mid-offer.',
                    granted: perms.overlayGranted,
                    buttonLabel: 'Grant “Display over other apps”',
                    onGrant: _grantOverlay,
                  ),
                  _GrantPage(
                    emoji: '👀',
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
                  child: Text(_page < 2 ? 'Next' : 'Start driving smarter'),
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

/// Intro page: mark, headline, body, optional footer (grant button / chip).
class _Page extends StatelessWidget {
  const _Page({
    required this.emoji,
    required this.title,
    required this.body,
    this.footer,
  });

  final String emoji;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: Gap.lg),
          Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
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
    );
  }
}

/// A [_Page] whose footer is the grant button, flipping to a green ✅ chip once
/// the permission is actually held (state re-checked on app resume).
class _GrantPage extends StatelessWidget {
  const _GrantPage({
    required this.emoji,
    required this.title,
    required this.body,
    required this.granted,
    required this.buttonLabel,
    required this.onGrant,
  });

  final String emoji;
  final String title;
  final String body;
  final bool granted;
  final String buttonLabel;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return _Page(
      emoji: emoji,
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

class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == page ? FoxColors.brandFox : FoxColors.border,
            ),
          ),
      ],
    );
  }
}
