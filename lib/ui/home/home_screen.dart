import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/car_reminder.dart';
import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../services/offer_log.dart';
import '../history/offer_detail_sheet.dart';
import '../overlay/overlay_controller.dart';
import '../settings/reminder_controller.dart';
import '../settings/settings_controller.dart';
import '../shell/root_shell.dart';
import '../theme/car_hero.dart';
import '../theme/platform_badge.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'profile_card.dart';
import 'shift_recap_sheet.dart';
import 'slide_to_live.dart';

/// Home dashboard (references/foxyco_home_v3.html).
///
/// A brand bar + a near-black "receipt" hero (today's tally, pause, the
/// good/ok/bad split) + the last scored offer as a torn ticket. The driver's
/// #1 question — "is it actually watching?" — is answered by the hero status
/// row and the live pill up top.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);
    final blocked = state.status == WatchStatus.blocked;

    return ListView(
      // Bottom pad must clear the floating nav: 64 bar + margins PLUS the
      // device's gesture-bar inset (extendBody lets content run under it —
      // a fixed 100 left the demo button unreachable behind the nav on
      // gesture-nav phones, device 2026-07-18).
      // Horizontal padding lives on the children (not the ListView) so the
      // showroom car can bleed edge-to-edge like the reference mock.
      padding: EdgeInsets.fromLTRB(
        0,
        Gap.sm,
        0,
        100 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        const _Padded(child: _BrandBar()),
        const SizedBox(height: Gap.sm),
        // Hidden (zero-height, incl. its own bottom pad) until a name is set.
        const _Padded(child: ProfileCard()),
        // The car sits on the page itself, full-bleed above the receipt card
        // (references/car/foxyco_hero_home (1).html) — not boxed inside it.
        _CarStage(online: state.status == WatchStatus.watching),
        const SizedBox(height: Gap.sm),
        _Padded(
          child: _Hero(
            status: state.status,
            tally: ref.watch(todayTallyProvider),
            yesterdayTotal: () {
              final y = ref.watch(yesterdayTallyProvider);
              return y.good + y.ok + y.bad;
            }(),
            platforms: ref.watch(settingsProvider).watchedApps.toList(),
            // Slide-to-go-live is the Start/Stop outer gate (spec M6 §3.2);
            // pause stays on the bubble long-press.
            onStart: controller.startMonitoring,
            onStop: () {
              final since = controller.stopMonitoring();
              maybeShowShiftRecap(
                context,
                liveSince: since,
                allOffers: ref.read(offerLogProvider),
              );
            },
            onFix: controller.requestMissingPermissions,
            onOpenSettings: () => ref.read(tabIndexProvider.notifier).go(2),
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (blocked) ...[
          _Padded(
            child: _AccessAlert(onFix: controller.requestMissingPermissions),
          ),
          const SizedBox(height: Gap.lg),
        ],
        // Car reminder inside its lead window — tap through to Settings.
        if (ref.watch(dueRemindersProvider).isNotEmpty) ...[
          _Padded(
            child: _ReminderBanner(
              reminder: ref.watch(dueRemindersProvider).first,
              onTap: () => ref.read(tabIndexProvider.notifier).go(2),
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],
        const _Padded(child: _SectionLabel('Last offer')),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Padded(child: _Ticket(offer: ref.watch(lastOfferProvider))),
        const SizedBox(height: Gap.md),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(overlayControllerProvider.notifier).simulateOffer(),
            child: Text(
              'Show a demo pill',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                // textSecondary + 12.5: 36%-alpha at 11.5px failed contrast.
                color: FoxColors.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: FoxColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Amber banner for the soonest due car reminder ("Safety inspection in 12
/// days"). Softer than the red access alert — informational, not blocking.
class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.reminder, required this.onTap});

  final CarReminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = reminder.daysLeft();
    final when = days < 0
        ? '${-days} days overdue'
        : days == 0
        ? 'today'
        : days == 1
        ? 'tomorrow'
        : 'in $days days';
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.cardSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: days < 0 ? VerdictColors.badBg : VerdictColors.okBg,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(
            color: (days < 0 ? VerdictColors.bad : VerdictColors.ok).withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 18,
              color: days < 0 ? VerdictColors.bad : VerdictColors.ok,
            ),
            const SizedBox(width: Gap.sm + Gap.xs),
            Expanded(
              child: Text(
                '${reminder.title} $when'
                '${reminder.note.isEmpty ? '' : ' — ${reminder.note}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: FoxColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: FoxColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard page gutter for everything except the full-bleed car.
class _Padded extends StatelessWidget {
  const _Padded({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
    child: child,
  );
}

/// Brand mark + name + a Live/Paused status pill.
class _BrandBar extends ConsumerWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(dashboardProvider).status != WatchStatus.watching;
    return Row(
      children: [
        // Full fox head in-app; the round disc PNG is the floating bubble's
        // only (user 2026-07-20).
        Image.asset('assets/branding/foxyco_head.png', width: 32, height: 32),
        const SizedBox(width: Gap.sm + Gap.xs),
        Text('FoxyCo', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        _LivePill(paused: paused),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.paused});
  final bool paused;

  @override
  Widget build(BuildContext context) {
    // Off state must stay on a DARK chip: cream text/dot on a cream pill was
    // invisible — the header showed a blank white capsule (device 2026-07-18).
    final color = paused ? FoxColors.textSecondary : VerdictColors.good;
    final bg = paused ? FoxColors.bgSurface2 : VerdictColors.goodBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: paused ? Border.all(color: FoxColors.border) : null,
        boxShadow: Shadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: paused ? FoxColors.textDisabled : VerdictColors.good,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            paused ? 'Off' : 'Live',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The near-black receipt hero: today's tally + go-live/stop + the split.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.status,
    required this.tally,
    required this.yesterdayTotal,
    required this.platforms,
    required this.onStart,
    required this.onStop,
    required this.onFix,
    required this.onOpenSettings,
  });

  final WatchStatus status;
  final Tally tally;
  final int yesterdayTotal;
  final List<GigPlatform> platforms;
  final VoidCallback onStart; // begin monitoring
  final VoidCallback onStop; // stop monitoring
  final VoidCallback onFix; // grant missing permission
  final VoidCallback onOpenSettings; // platform badges tap-through

  @override
  Widget build(BuildContext context) {
    final online = status == WatchStatus.watching;
    final total = tally.good + tally.ok + tally.bad;
    final statusText = switch (status) {
      WatchStatus.watching => 'On the prowl',
      WatchStatus.paused => 'Off duty',
      WatchStatus.stopped => 'Ready when you are',
      WatchStatus.blocked => 'Access needed',
    };
    final paused = !online;

    return Container(
      // Tighter than Gap.lg all around — every vertical px here pushes
      // slide-to-live toward/below the fold.
      padding: const EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.md + Gap.xs,
        Gap.lg,
        Gap.md + Gap.xs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        // Live: warm orange edge + soft glow so the main card visibly
        // "powers up" with the car (premium pass 2026-07-20).
        border: Border.all(
          color: paused
              ? FoxColors.border
              : FoxColors.brandFox.withValues(alpha: 0.35),
        ),
        boxShadow: [
          ...Shadows.hero,
          if (!paused)
            BoxShadow(
              color: FoxColors.brandFox.withValues(alpha: 0.10),
              blurRadius: 32,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: paused ? FoxColors.textDisabled : FoxColors.brandFox,
                  shape: BoxShape.circle,
                  boxShadow: paused
                      ? null
                      : [
                          BoxShadow(
                            color: FoxColors.brandFox.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.creamDim,
                ),
              ),
              const Spacer(),
              // Tap the badges → Settings (watched-apps live there); they
              // were dead decorative pixels before.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenSettings();
                },
                child: Row(
                  children: [
                    for (final p in platforms) ...[
                      PlatformBadge(platform: p),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          // Compact stat row (ref mock): number + wrapped caption left,
          // "vs yesterday" trend chip right — keeps slide-to-live above the
          // fold on common phones.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FittedBox: 5+ digit days (log caps at 2000/day anyway) scale
              // down instead of overflowing the row.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: total),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : Motion.count,
                    curve: Motion.curve,
                    builder: (context, value, _) => Text(
                      '$value',
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 46,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.5,
                        color: FoxColors.cream,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Text(
                  'offers seen\ntoday',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: FoxColors.cream.withValues(alpha: 0.55),
                  ),
                ),
              ),
              _TrendChip(today: total, yesterday: yesterdayTotal),
            ],
          ),
          const SizedBox(height: Gap.md),
          _SegBar(tally: tally),
          const SizedBox(height: Gap.sm + Gap.xs),
          _SegLegend(tally: tally),
          const SizedBox(height: Gap.md),
          SlideToLive(
            status: status,
            onStart: onStart,
            onStop: onStop,
            onFix: onFix,
          ),
        ],
      ),
    );
  }
}

/// "vs yesterday" trend chip (ref mock): green up / red down / neutral dash.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.today, required this.yesterday});
  final int today;
  final int yesterday;

  @override
  Widget build(BuildContext context) {
    // No yesterday baseline → "+11 vs yesterday" is meaningless; show a
    // neutral "first day" chip instead.
    if (yesterday == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface2.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(color: FoxColors.borderSoft),
        ),
        child: const Text(
          'first day',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: FoxColors.textDisabled,
          ),
        ),
      );
    }
    final diff = today - yesterday;
    final up = diff > 0;
    final flat = diff == 0;
    final color = flat
        ? FoxColors.textSecondary
        : up
        ? VerdictColors.good
        : VerdictColors.bad;
    final label = flat
        ? '–'
        : '${up ? '+' : ''}${(diff * 100 / yesterday).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!flat)
                Icon(
                  up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 15,
                  color: color,
                ),
              if (!flat) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'vs yesterday',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: FoxColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// The showroom car on the home page (references/car/foxyco_hero_home (1).html).
/// Live → full reveal, lights on; off → stealth, lights dim. The crossfade is
/// a 600ms tween; on top runs one idle loop — a 3.2s glow pulse. Car body
/// stays FIXED (no float — device feedback 2026-07-20). Pulse skipped under
/// reduced motion.
class _CarStage extends StatefulWidget {
  const _CarStage({required this.online});
  final bool online;

  @override
  State<_CarStage> createState() => _CarStageState();
}

class _CarStageState extends State<_CarStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle; // 0..1 looping, drives float + pulse

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _idle.repeat();
      }
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.online ? 1.0 : 0.0),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, lit, _) => AnimatedBuilder(
        animation: _idle,
        builder: (context, _) {
          final t = _idle.value;
          // Pulse: ~2 cycles per 6s loop (≈3s, matching the mock's 3.2s
          // glowpulse), scaling the glows only — car body stays fixed.
          final pulse = reduced ? 1.0 : 0.85 + 0.15 * math.sin(4 * math.pi * t);
          final base = CarHeroState.lerp(
            CarHeroState.stealth,
            CarHeroState.reveal,
            lit,
          );
          final state = CarHeroState(
            shadow: base.shadow,
            stealthBacklight: base.stealthBacklight * pulse,
            fogRear: base.fogRear,
            carStealth: base.carStealth,
            fogFront: base.fogFront,
            rimLight: base.rimLight,
            headlightBeams: base.headlightBeams,
            revealBacklight: base.revealBacklight * pulse,
            groundGlow: base.groundGlow * pulse,
            carReveal: base.carReveal,
            bodyAccent: base.bodyAccent,
            grilleLights: base.grilleLights,
            headlightsSharp: base.headlightsSharp,
            interiorGlow: base.interiorGlow,
            reflection: base.reflection,
          );
          // Crop the canvas' empty top/bottom bands (~80% height keeps some
          // air around the car without pushing slide-to-live off-screen).
          // Car pixels span 98% of the canvas width — inset slightly so the
          // nose/tail don't kiss the screen edges (ref mock has margin).
          return ClipRect(
            child: Align(
              alignment: const Alignment(0, -0.2),
              heightFactor: 0.8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: CarHero(state: state),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The proportional good/ok/bad bar inside the hero. Segments grow into place
/// (spec M6 §3.3); an empty tally leaves the tinted track showing.
class _SegBar extends StatelessWidget {
  const _SegBar({required this.tally});
  final Tally tally;

  @override
  Widget build(BuildContext context) {
    final total = tally.good + tally.ok + tally.bad;
    final reduced = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        height: 16,
        color: FoxColors.cream.withValues(alpha: 0.08),
        child: total == 0
            ? null // empty tally -> track shows through (spec M6 §3.3)
            : LayoutBuilder(
                builder: (context, c) => Row(
                  children: [
                    for (final (count, color) in [
                      (tally.good, VerdictColors.good),
                      (tally.ok, VerdictColors.ok),
                      (tally.bad, VerdictColors.bad),
                    ])
                      AnimatedContainer(
                        duration: reduced ? Duration.zero : Motion.base,
                        curve: Motion.curve,
                        width: c.maxWidth * count / total,
                        color: color,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SegLegend extends StatelessWidget {
  const _SegLegend({required this.tally});
  final Tally tally;

  @override
  Widget build(BuildContext context) {
    // Three equal-width pills under the bar (ref mock) — centered content,
    // verdict-tinted like the mock's Good/Okay/Bad chips.
    return Row(
      children: [
        Expanded(
          child: _LegendItem(VerdictColors.goodOnDark, tally.good, 'good'),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(child: _LegendItem(VerdictColors.okOnDark, tally.ok, 'ok')),
        const SizedBox(width: Gap.sm),
        Expanded(child: _LegendItem(VerdictColors.badOnDark, tally.bad, 'bad')),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.count, this.label);
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: const TextStyle(
                    color: FoxColors.cream,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  style: TextStyle(color: color.withValues(alpha: 0.9)),
                ),
              ],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accessibility-not-granted banner (mirrors the mockup's alert row).
class _AccessAlert extends StatelessWidget {
  const _AccessAlert({required this.onFix});
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: VerdictColors.badBg,
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: VerdictColors.bad.withValues(alpha: 0.35)),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: VerdictColors.bad,
            size: 22,
          ),
          const SizedBox(width: Gap.sm + Gap.xs),
          Expanded(
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'Accessibility off. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: "FoxyCo can't read offers until it's on."),
                ],
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: FoxColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              foregroundColor: VerdictColors.bad,
              backgroundColor: FoxColors.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            child: const Text(
              'Fix',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: Gap.sm + Gap.xs),
        const Expanded(child: Divider(color: FoxColors.border, height: 1)),
      ],
    );
  }
}

/// The last offer as a torn ticket: verdict badge + app + time up top, a
/// perforated divider, then distance / fare / $-per-km along the bottom.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.offer});
  final OfferSummary? offer;

  @override
  Widget build(BuildContext context) {
    if (offer == null) return const _EmptyTicket();

    final o = offer!;
    final style = VerdictStyle.of(o.verdict);
    // Locale-aware (12h markets see "6:48 PM", not hardcoded 24h).
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(o.seenAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final fare = o.payout == o.payout.roundToDouble()
        ? '\$${o.payout.toStringAsFixed(0)}'
        : '\$${o.payout.toStringAsFixed(2)}';

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.card),
      onTap: () => showOfferDetail(context, o),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FoxColors.inkSoft, FoxColors.ink],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: FoxColors.borderSoft),
          boxShadow: Shadows.card,
        ),
        child: Column(
          children: [
            // Top: verdict badge + app + time. A verdict-colored spine runs
            // down the left edge.
            IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: style.color,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: style.color.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              style.label == '—' ? '—' : _title(style.label),
                              style: TextStyle(
                                fontFamily: FoxFonts.display,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: style.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.sm + Gap.xs),
                          Text(
                            o.platform.label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: FoxColors.textDisabled,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TicketStat(
                      '${o.totalKm.toStringAsFixed(1)} km',
                      'DISTANCE',
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(child: _TicketStat(fare, 'FARE')),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: _TicketStat(
                      '\$${o.pricePerKm.toStringAsFixed(2)}',
                      'PER KM',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _title(String upper) =>
      upper[0] + upper.substring(1).toLowerCase();
}

class _TicketStat extends StatelessWidget {
  const _TicketStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Tinted well matching the pill's stat rows — value on top, label under.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // scaleDown, not ellipsis: "11.0 …" on the distance well looked
          // broken (device 2026-07-20).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: FoxFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FoxColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: FoxColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed perforation with notch cut-outs on each side — the torn-ticket seam.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: List.generate(
                  (c.maxWidth / 10).floor(),
                  (_) => Container(
                    width: 5,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    color: FoxColors.border,
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: -10, child: _notch()),
          Positioned(right: -10, child: _notch()),
        ],
      ),
    );
  }

  Widget _notch() => Container(
    width: 20,
    height: 20,
    decoration: const BoxDecoration(
      color: FoxColors.bgBase,
      shape: BoxShape.circle,
    ),
  );
}

class _EmptyTicket extends StatelessWidget {
  const _EmptyTicket();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        children: [
          Image.asset('assets/branding/foxyco_head.png', width: 64, height: 64),
          const SizedBox(height: Gap.sm),
          Text('No offers yet 🍪', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            "Open Uber or Hopp and drive — I'll sniff out the tasty ones.",
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
