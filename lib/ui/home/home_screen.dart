import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/car_reminder.dart';
import '../../domain/fox_settings.dart';
import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../parser/parser_registry.dart';
import '../../domain/session_summary.dart';
import '../../services/offer_log.dart';
import '../../services/session_log.dart';
import '../overlay/overlay_controller.dart';
import '../paywall/access_banner.dart';
import '../legal/accessibility_disclosure.dart';
import '../settings/reminder_controller.dart';
import '../settings/settings_controller.dart';
import '../shell/root_shell.dart';
import '../theme/car_hero.dart';
import '../theme/hero_stage.dart';
import '../theme/platform_badge.dart';
import '../theme/section_label.dart';
import '../theme/tokens.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'fox_tips_card.dart';
import 'profile_card.dart';
import 'recap_widgets.dart';
import 'slide_to_live.dart';
import 'update_prompt.dart';

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
    final settings = ref.watch(settingsProvider);
    final blocked = state.status == WatchStatus.blocked;
    final recentAccepted = ref
        .watch(offerLogProvider)
        .where(
          (offer) =>
              offer.outcome == OfferOutcome.taken ||
              offer.outcome == OfferOutcome.completed,
        )
        .take(3)
        .toList();
    Future<void> requestMissingPermissions() =>
        controller.requestMissingPermissions(
          confirmAccessibility: () => showAccessibilityDisclosure(context),
        );

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
        112 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        const _Padded(child: _BrandBar()),
        const SizedBox(height: Gap.sm),
        // Trial countdown / unlock ask / offline-check warning. Zero height when
        // there's nothing to say, which is the normal case.
        const _Padded(child: AccessBanner()),
        if (state.status != WatchStatus.watching &&
            state.status != WatchStatus.paused)
          const _Padded(child: PlayUpdatePrompt()),
        // Hidden (zero-height, incl. its own bottom pad) until a name is set.
        const _Padded(child: ProfileCard()),
        // The car sits on the page itself, full-bleed above the receipt card
        // (references/car/foxyco_hero_home (1).html) — not boxed inside it,
        // except in light mode where it gets a showroom panel. Gap.md above and
        // below in BOTH themes: at Gap.sm the greeting and the receipt card
        // crowded it (device 2026-07-25).
        const SizedBox(height: Gap.md),
        // Status + clock ride ABOVE the car, on the page. The ref mock floats
        // them inside the panel; on device that only works when the panel is a
        // frame you can overlay — the car is full-bleed in dark mode, so they'd
        // sit on the paint (user 2026-07-25).
        _Padded(child: _CarStatusBar(status: state.status)),
        const SizedBox(height: Gap.sm + Gap.xs),
        _CarStage(online: state.status == WatchStatus.watching),
        const SizedBox(height: Gap.md),
        _Padded(
          child: _Hero(
            status: state.status,
            tally: ref.watch(todayTallyProvider),
            yesterdayTotal: () {
              final y = ref.watch(yesterdayTallyProvider);
              return y.good + y.ok + y.bad;
            }(),
            platforms: ParserRegistry.supportedPlatforms
                .where(settings.watches)
                .toList(),
            // Slide-to-go-live is the Start/Stop outer gate (spec M6 §3.2);
            // pause stays on the bubble long-press.
            onStart: () => settings.watchedApps.isEmpty
                ? ref.read(tabIndexProvider.notifier).go(1, section: 3)
                : unawaited(controller.startMonitoring()),
            onStop: controller.stopMonitoring,
            onFix: requestMissingPermissions,
            // Rules section 3 is "Watched apps" — the badges' own controls.
            // on Settings with it still collapsed and off-screen isn't a jump,
            // it's a hint.
            onOpenSettings: () =>
                ref.read(tabIndexProvider.notifier).go(1, section: 3),
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (blocked) ...[
          _Padded(child: _AccessAlert(onFix: requestMissingPermissions)),
          const SizedBox(height: Gap.lg),
        ],
        // Car reminder inside its lead window — tap through to Settings' Garage
        // group (section 1), where the reminders themselves live.
        if (ref.watch(dueRemindersProvider).isNotEmpty) ...[
          _Padded(
            child: _ReminderBanner(
              reminder: ref.watch(dueRemindersProvider).first,
              onTap: () =>
                  ref.read(tabIndexProvider.notifier).go(3, section: 1),
            ),
          ),
          const SizedBox(height: Gap.lg),
        ],
        const _Padded(child: SectionLabel('Last session')),
        const SizedBox(height: Gap.sm + Gap.xs),
        // Tap through to History — the card summarises offers the driver has no
        // other way to reach from Home.
        _Padded(
          child: _SessionCard(
            session: ref.watch(lastSessionProvider),
            onTap: () => ref.read(tabIndexProvider.notifier).go(2),
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (recentAccepted.isNotEmpty) ...[
          _Padded(child: _RecentAccepted(offers: recentAccepted)),
          const SizedBox(height: Gap.lg),
        ],
        const _Padded(child: SectionLabel('Fox tips')),
        const SizedBox(height: Gap.sm + Gap.xs),
        const _Padded(child: FoxTipsCard()),
        const SizedBox(height: Gap.md),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(overlayControllerProvider.notifier).simulateOffer(),
            child: Text(
              'Preview an offer',
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

class _RecentAccepted extends ConsumerStatefulWidget {
  const _RecentAccepted({required this.offers});

  final List<OfferSummary> offers;

  @override
  ConsumerState<_RecentAccepted> createState() => _RecentAcceptedState();
}

class _RecentAcceptedState extends ConsumerState<_RecentAccepted> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.md),
    decoration: BoxDecoration(
      color: FoxColors.bgSurface,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: FoxColors.borderSoft),
      boxShadow: Shadows.card,
    ),
    child: Column(
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  color: FoxColors.brandFox,
                  size: 22,
                ),
                const SizedBox(width: Gap.sm + Gap.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent accepted',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FoxColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _expanded
                            ? 'Tap a trip to update its payout'
                            : '${widget.offers.length} recent ${widget.offers.length == 1 ? 'trip' : 'trips'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: FoxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: FoxColors.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: Gap.md),
          for (var i = 0; i < widget.offers.length; i++) ...[
            _AcceptedTripTimelineItem(
              key: ValueKey(
                'recent-accepted-${widget.offers[i].seenAt.microsecondsSinceEpoch}',
              ),
              offer: widget.offers[i],
              isFirst: i == 0,
              isLast: i == widget.offers.length - 1,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(pendingOfferProvider.notifier).set(widget.offers[i]);
              },
            ),
          ],
        ],
      ],
    ),
  );
}

class _AcceptedTripTimelineItem extends ConsumerWidget {
  const _AcceptedTripTimelineItem({
    super.key,
    required this.offer,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final OfferSummary offer;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final snapshot = offer.scoringSnapshot;
    final currency = snapshot?.currency ?? settings.currency;
    final unit = snapshot?.distanceUnit ?? settings.distanceUnit;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(offer.seenAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final platformColor = switch (offer.platform) {
      GigPlatform.uber || GigPlatform.uberEats => FoxColors.uber,
      _ => Color(offer.platform.colorValue),
    };
    final distance =
        '${unit.distanceFromKm(offer.totalKm).toStringAsFixed(1)} ${unit.shortLabel}';
    final payout =
        '${currency.symbol}${offer.effectivePayout.toStringAsFixed(2)}';
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '${offer.platform.label}, accepted, $payout, $time, $distance',
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            Positioned(
              left: 15,
              top: isFirst ? 30 : 0,
              bottom: isLast ? 30 : 0,
              child: Container(width: 2, color: FoxColors.brandFox),
            ),
            Positioned(
              left: 3,
              top: 18,
              child: PlatformBadge(
                key: ValueKey(
                  'recent-accepted-platform-${offer.seenAt.microsecondsSinceEpoch}',
                ),
                platform: offer.platform,
                size: 24,
              ),
            ),
            Positioned.fill(
              left: 32,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.field),
                    gradient: LinearGradient(
                      colors: [
                        platformColor.withValues(alpha: dark ? 0.18 : 0.10),
                        platformColor.withValues(alpha: dark ? 0.06 : 0.025),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.field),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 225 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.2;
                          return Row(
                            children: [
                              Expanded(
                                child: compact
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _AcceptedTripPayout(payout),
                                          const SizedBox(height: 2),
                                          _AcceptedTripDetails(
                                            time: time,
                                            distance: distance,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Flexible(
                                            flex: 4,
                                            child: _AcceptedTripPayout(payout),
                                          ),
                                          const SizedBox(width: Gap.sm),
                                          Expanded(
                                            flex: 5,
                                            child: _AcceptedTripDetails(
                                              time: time,
                                              distance: distance,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: Gap.xs),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: FoxColors.textSecondary,
                                size: 22,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isLast)
              Positioned(
                left: 32,
                right: Gap.sm,
                bottom: 0,
                child: Container(height: 1, color: FoxColors.borderSoft),
              ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedTripPayout extends StatelessWidget {
  const _AcceptedTripPayout(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      maxLines: 1,
      style: TextStyle(
        fontFamily: FoxFonts.display,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: FoxColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _AcceptedTripDetails extends StatelessWidget {
  const _AcceptedTripDetails({required this.time, required this.distance});

  final String time;
  final String distance;

  @override
  Widget build(BuildContext context) => Text(
    '$time  ·  $distance',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: FoxColors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
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
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: FoxColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Icon(
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
class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    // Wordmark only. The Live/Off pill that used to sit on the right is gone
    // (user 2026-07-25) — the status chip above the car says the same thing in
    // full, and the slide bar below it is the control. Three copies of "Live"
    // in one viewport was two too many.
    return Row(
      children: [
        // Full fox head in-app; the round disc PNG is the floating bubble's
        // only (user 2026-07-20).
        Image.asset('assets/branding/foxyco_head.png', width: 32, height: 32),
        const SizedBox(width: Gap.sm + Gap.xs),
        Text('FoxyCo', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// A softly breathing status dot: a slow glow-pulse + gentle scale on a loop,
/// signalling "online / alive". Static under reduced motion.
class _BreathingDot extends StatefulWidget {
  const _BreathingDot({required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true); // build() stops it if reduced motion is on
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced && _c.isAnimating) _c.stop();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = reduced ? 0.0 : _c.value;
        return Transform.scale(
          scale: 1 + 0.18 * t,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: reduced
                  ? null
                  : [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.3 + 0.45 * t),
                        blurRadius: 4 + 7 * t,
                      ),
                    ],
            ),
          ),
        );
      },
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
      WatchStatus.watching => 'Watching offers',
      WatchStatus.paused => 'Paused',
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
        gradient: LinearGradient(
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
              // Bounded: "Ready when you are" plus three app badges overran a
              // 320 dp card at large text scales (overflow audit 2026-07-25).
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.creamDim,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              // Tap the badges → Settings (watched-apps live there); they
              // were dead decorative pixels before.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenSettings();
                },
                child: Row(children: [PlatformBadges(platforms: platforms)]),
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
          if (status != WatchStatus.blocked)
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

  static const _minimumPercentageBaseline = 10;

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
        child: Text(
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
    // Percentages with a tiny denominator are technically correct but poor
    // driving UX (for example 6 vs 1 becomes +500%). Keep the raw comparison
    // visible until yesterday has a meaningful activity sample.
    if (yesterday < _minimumPercentageBaseline) {
      final label = diff == 0
          ? 'same as yesterday'
          : diff > 0
          ? '$diff more than yesterday'
          : '${-diff} fewer than yesterday';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface2.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(color: FoxColors.borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: diff == 0 ? FoxColors.textSecondary : VerdictColors.good,
          ),
        ),
      );
    }
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
          Text(
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

/// Live-status chip + clock, on the page directly above the showroom card.
///
/// The ref mock puts both inside the card's top corners; here they sit above it
/// (user 2026-07-25) so the card holds nothing but the car in either theme. The
/// header keeps its own Live/Off pill — this one names the state in full
/// ("Live Status / Offline") the way the mock does.
class _CarStatusBar extends StatefulWidget {
  const _CarStatusBar({required this.status});
  final WatchStatus status;

  @override
  State<_CarStatusBar> createState() => _CarStatusBarState();
}

class _CarStatusBarState extends State<_CarStatusBar> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Wake on the minute BOUNDARY, not every 60 s from mount — a fixed period
  /// drifts up to a minute out of step with the phone's own clock, which is the
  /// one the driver compares it against.
  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _tick = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final online = widget.status == WatchStatus.watching;
    final label = switch (widget.status) {
      WatchStatus.watching => 'Live',
      WatchStatus.paused => 'Paused',
      WatchStatus.stopped => 'Offline',
      WatchStatus.blocked => 'Offline',
    };
    // Sun by day, moon after dark — the mock's weather glyph, driven by the
    // same clock rather than a forecast we don't have.
    final day = _now.hour >= 6 && _now.hour < 19;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(color: FoxColors.borderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              online
                  ? _BreathingDot(color: VerdictColors.good, size: 7)
                  : Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: FoxColors.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
              const SizedBox(width: Gap.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Live Status',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: FoxColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: online
                          ? VerdictColors.good
                          : FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Icon(
          day ? Icons.wb_sunny_rounded : Icons.nightlight_round,
          size: 18,
          color: day ? VerdictColors.okFill : FoxColors.textSecondary,
        ),
        const SizedBox(width: Gap.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.formatTimeOfDay(
                TimeOfDay.fromDateTime(_now),
                alwaysUse24HourFormat: MediaQuery.of(
                  context,
                ).alwaysUse24HourFormat,
              ),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: FoxColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              l10n.formatMediumDate(_now),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The showroom car on the home page (Foxy brand art, 2026-07-26).
/// Live → the glow behind the car blooms; off → it sits at a quarter strength.
/// The crossfade is a 600ms tween. Car body stays FIXED (no float — device
/// feedback 2026-07-20); the stage owns every ambient loop.
class _CarStage extends StatelessWidget {
  const _CarStage({required this.online});
  final bool online;

  /// Glow opacity offline. Not 0 — the layer carries the contact shadow too, so
  /// at zero the car floats.
  static const _glowOff = 0.25;

  /// Same crop for the car AND its sweep mask: the two have to land on the same
  /// pixels. Shows the 0.10–0.92 band of the canvas: the empty top is cropped, and
  /// so is the dead strip under the wheels, which is what used to leave the car
  /// hovering mid-card (device 2026-07-26). Alignment y is solved from the
  /// band: top = (1 + y) / 2 * (1 − heightFactor) = 0.10.
  ///
  /// Keep one 8 dp showroom gutter above that crop. Without it, the fox ears
  /// visually touch the stage edge even though the source canvas has padding.
  /// Adding height here (instead of translating the raster) also moves the
  /// stage's proportional floor line with the wheels and avoids bottom clipping.
  static Widget _framed(Widget layer) => Padding(
    padding: const EdgeInsets.only(top: Gap.sm),
    child: ClipRect(
      child: Align(
        alignment: const Alignment(0, 0.111),
        heightFactor: 0.82,
        child: layer,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final light = FoxColors.palette.brightness == Brightness.light;
    // Decode the sweep mask at display width, not the asset's 1536 px.
    final maskW =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: online ? 1.0 : 0.0),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        builder: (context, lit, _) {
          // Light theme's back layer is a plain shadow, not a glow: fading it up
          // would read as the shadow arriving, not the car lighting up. There it
          // stays put and the stage's warm border + halo below carry the live
          // tell on their own.
          // ponytail: one animated value. If light mode ends up needing its own
          // car-level cue, that's a second art layer, not more code here.
          final glow = light ? 1.0 : _glowOff + (1 - _glowOff) * lit;
          return HeroStage(
            // Live: the verdict pill's orbiting plasma language, recolored to
            // Foxy orange so this reads as service status rather than a score.
            plasmaColor: online ? FoxColors.brandFox : null,
            silhouette: _framed(
              AspectRatio(
                aspectRatio: CarHero.canvas,
                child: Image.asset(
                  CarHero.coreAsset,
                  fit: BoxFit.contain,
                  cacheWidth: maskW,
                ),
              ),
            ),
            child: _framed(CarHero(glow: glow, onDark: !light)),
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
    // 11dp, not 16, with the segments separated rather than butted together:
    // three saturated blocks in one unbroken slab read as a heavy stripe across
    // the card (device 2026-07-25: "colors are too thick"). Each segment gets
    // its own rounded pill and a top-lit gradient, so the row reads as three
    // lozenges resting in a track instead of one painted band.
    return Container(
      height: 11,
      decoration: BoxDecoration(
        color: FoxColors.cream.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      padding: const EdgeInsets.all(1.5),
      child: total == 0
          ? null // empty tally -> track shows through (spec M6 §3.3)
          : LayoutBuilder(
              builder: (context, c) {
                final segs = [
                  (tally.good, VerdictColors.goodFill),
                  (tally.ok, VerdictColors.okFill),
                  (tally.bad, VerdictColors.badFill),
                ].where((s) => s.$1 > 0).toList();
                return Row(
                  children: [
                    for (final (i, (count, color)) in segs.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      AnimatedContainer(
                        duration: reduced ? Duration.zero : Motion.base,
                        curve: Motion.curve,
                        width:
                            (c.maxWidth - 3 - 2 * (segs.length - 1)) *
                            count /
                            total,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          // Lit from above, like everything else on the page.
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(color, Colors.white, 0.18)!,
                              color,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
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
        Expanded(child: _LegendItem(VerdictColors.good, tally.good, 'good')),
        const SizedBox(width: Gap.sm),
        Expanded(child: _LegendItem(VerdictColors.ok, tally.ok, 'ok')),
        const SizedBox(width: Gap.sm),
        Expanded(child: _LegendItem(VerdictColors.bad, tally.bad, 'bad')),
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
                  style: TextStyle(
                    color: FoxColors.cream,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  // Full strength: at 0.9 the amber "ok" label read as faded
                  // (device 2026-07-25), and it's the weakest of the three
                  // hues to begin with — it can't afford a 10% haircut.
                  style: TextStyle(color: color),
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
          Icon(Icons.warning_amber_rounded, color: VerdictColors.bad, size: 22),
          const SizedBox(width: Gap.sm + Gap.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Offer access is off. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'Tap Fix to enable it.'),
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

/// The last completed watch session (replaced the "Last offer" ticket,
/// device 2026-07-21). Rebuilt on the shift-recap sheet's layout (device
/// 2026-07-24: "why can't the card look like the recap?") — a header row that
/// dates the session, the offer count, the verdict split, then the same three
/// stat tiles. The shared pieces live in [recap_widgets] so card and sheet
/// can't drift.
///
/// The date is spelled out for EVERY session, today's included. It used to be
/// dropped on a same-day session, which read as "this is current" the morning
/// after a night shift.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.onTap});
  final SessionSummary? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = session;
    // Nothing to show yet → nothing to open; the empty card's own copy points
    // at the slide instead.
    if (s == null) return const _EmptySession();

    final text = Theme.of(context).textTheme;
    final l10n = MaterialLocalizations.of(context);
    // Locale-aware times (12h markets see "6:48 PM", not hardcoded 24h).
    String clock(DateTime t) => l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final now = DateTime.now();
    final endedDay = DateUtils.dateOnly(s.endedAt);
    final daysAgo = DateUtils.dateOnly(now).difference(endedDay).inDays;
    final day = switch (daysAgo) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => l10n.formatShortDate(s.endedAt),
    };

    // GestureDetector, not InkWell: the card paints its own gradient, which
    // would sit on top of the ripple anyway.
    return Semantics(
      button: true,
      hint: 'Open History',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FoxColors.inkSoft, FoxColors.ink],
            ),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: FoxColors.borderSoft),
            boxShadow: Shadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day + clock range on the left, time-on-watch on the right. Both
              // sides are bounded: the old version let an unbounded date string
              // run straight out of the card (device 2026-07-25).
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: FoxColors.cream,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${clock(s.startedAt)} – ${clock(s.endedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: FoxColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  // Own Row so the icon centers against the digits. Inheriting the
                  // outer row's CrossAxisAlignment.start top-aligned a 15px icon
                  // box with a 17px text box, which left the icon riding high
                  // (device 2026-07-25).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: FoxColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        durationLabel(s.duration),
                        style: TextStyle(
                          fontFamily: FoxFonts.display,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: FoxColors.cream,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              _SessionVolume(session: s, text: text),
              if (s.total == 0) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  'No offers appeared while FoxyCo was live.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: Gap.sm + Gap.xs),
                _SessionQuality(session: s),
                const SizedBox(height: Gap.sm),
                SessionPerformance(session: s, settings: settings, text: text),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionVolume extends StatelessWidget {
  const _SessionVolume({required this.session, required this.text});

  final SessionSummary session;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _volumeMetric(
          '${session.total}',
          session.total == 1 ? 'offer scored' : 'offers scored',
          text.titleLarge?.copyWith(
            fontFamily: FoxFonts.display,
            fontSize: 36,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: FoxColors.cream,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const SizedBox(width: Gap.md),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm + Gap.xs,
          ),
          decoration: BoxDecoration(
            color: VerdictColors.goodBg,
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(
              color: VerdictColors.good.withValues(alpha: 0.28),
            ),
          ),
          child: _volumeMetric(
            '${session.accepted}',
            'accepted',
            text.titleMedium?.copyWith(
              fontFamily: FoxFonts.display,
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w700,
              color: FoxColors.cream,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            icon: Icons.check_circle_outline,
          ),
        ),
      ),
    ],
  );

  Widget _volumeMetric(
    String value,
    String label,
    TextStyle? valueStyle, {
    IconData? icon,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: VerdictColors.good),
            const SizedBox(width: Gap.xs),
          ],
          Text(value, style: valueStyle),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: icon == null ? FoxColors.textSecondary : VerdictColors.good,
        ),
      ),
    ],
  );
}

class _SessionQuality extends StatelessWidget {
  const _SessionQuality({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final total = session.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.sm),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Offer quality',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FoxColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'View details  ›',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: FoxColors.brandFox,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 9,
              child: Row(
                children: [
                  if (session.good > 0)
                    Expanded(
                      flex: session.good,
                      child: Container(color: VerdictColors.goodFill),
                    ),
                  if (session.ok > 0)
                    Expanded(
                      flex: session.ok,
                      child: Container(color: VerdictColors.okFill),
                    ),
                  if (session.bad > 0)
                    Expanded(
                      flex: session.bad,
                      child: Container(color: VerdictColors.badFill),
                    ),
                  if (total == 0)
                    Expanded(child: Container(color: FoxColors.border)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          VerdictSplitPills(
            good: session.good,
            ok: session.ok,
            bad: session.bad,
            fontSize: 11,
          ),
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  const _SessionStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(Gap.sm + Gap.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: Gap.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: FoxFonts.display,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: FoxColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: FoxColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class SessionPerformance extends StatefulWidget {
  const SessionPerformance({
    super.key,
    required this.session,
    required this.settings,
    required this.text,
  });

  final SessionSummary session;
  final FoxSettings settings;
  final TextTheme text;

  @override
  State<SessionPerformance> createState() => _SessionPerformanceState();
}

class _SessionPerformanceState extends State<SessionPerformance> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final settings = widget.settings;
    final text = widget.text;
    final earnings = session.earnings > 0
        ? '${settings.currency.symbol}${session.earnings.toStringAsFixed(2)}'
        : '—';
    final hourly = session.hourlyEarnings > 0
        ? '${settings.currency.symbol}${session.hourlyEarnings.toStringAsFixed(0)}/hr'
        : '—';
    final earningsColor = Theme.of(context).brightness == Brightness.light
        ? FoxColors.brandFoxDeep
        : FoxColors.brandFox;
    final metrics = [
      _SessionMetric(
        title: session.hasActualEarnings ? 'Actual earnings' : 'Est. earnings',
        value: earnings,
        support: session.earnings > 0
            ? session.hasActualEarnings
                  ? 'Trip payouts ${settings.currency.symbol}${session.estimatedEarnings.toStringAsFixed(2)} · ${session.earnings >= session.estimatedEarnings ? '+' : '−'}${settings.currency.symbol}${(session.earnings - session.estimatedEarnings).abs().toStringAsFixed(2)} adjustment'
                  : session.missingFinalPayouts > 0
                  ? '${session.missingFinalPayouts} ${session.missingFinalPayouts == 1 ? 'payout needs' : 'payouts need'} review'
                  : 'Trip payouts'
            : 'Accepted offers only',
        text: text,
        valueColor: earningsColor,
        valueKey: const ValueKey('session-performance-earnings'),
      ),
      _SessionMetric(
        title: 'Session rate',
        value: hourly == '—' ? hourly : hourly.replaceFirst('/hr', ''),
        support: 'Per active hour',
        text: text,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(Gap.sm + Gap.xs),
      decoration: BoxDecoration(
        color: FoxColors.brandFox.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: FoxColors.brandFox.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.query_stats_rounded,
                    size: 16,
                    color: VerdictColors.good,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: !_expanded && session.earnings <= 0
                        ? Text(
                            'No accepted offers this session',
                            key: const ValueKey(
                              'session-performance-collapsed',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textSecondary,
                            ),
                          )
                        : _expanded
                        ? Text(
                            'Session performance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textPrimary,
                            ),
                          )
                        : Text.rich(
                            key: const ValueKey(
                              'session-performance-collapsed',
                            ),
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: earnings,
                                  style: TextStyle(color: earningsColor),
                                ),
                                TextSpan(text: '   |   $hourly'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: FoxFonts.display,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: FoxColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: Gap.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: metrics[0]),
                const SizedBox(width: Gap.md),
                Expanded(child: metrics[1]),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                _SessionStat(
                  icon: Icons.route_rounded,
                  color: VerdictColors.good,
                  value: session.bestPerKm > 0
                      ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(session.bestPerKm).toStringAsFixed(2)}'
                      : '—',
                  label:
                      'Best \$/${settings.distanceUnit.shortLabel.toLowerCase()}',
                ),
                const SizedBox(width: Gap.sm),
                _SessionStat(
                  icon: Icons.trending_up_rounded,
                  color: VerdictColors.ok,
                  value: session.goodAvgPerKm > 0
                      ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(session.goodAvgPerKm).toStringAsFixed(2)}'
                      : '—',
                  label: 'Good avg',
                ),
                const SizedBox(width: Gap.sm),
                _SessionStat(
                  icon: Icons.schedule_rounded,
                  color: FoxColors.brandFox,
                  value: session.busiestHour != null
                      ? hourLabel(session.busiestHour!)
                      : '—',
                  label: 'Busiest',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionMetric extends StatelessWidget {
  const _SessionMetric({
    required this.title,
    required this.value,
    required this.support,
    required this.text,
    this.valueColor,
    this.valueKey,
  });

  final String title;
  final String value;
  final String support;
  final TextTheme text;
  final Color? valueColor;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FoxColors.textSecondary,
        ),
      ),
      const SizedBox(height: 2),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          key: valueKey,
          maxLines: 1,
          style: text.titleLarge?.copyWith(
            color: valueColor ?? FoxColors.cream,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      Text(
        support,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10.5, color: FoxColors.textSecondary),
      ),
    ],
  );
}

class _EmptySession extends StatelessWidget {
  const _EmptySession();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          Image.asset('assets/branding/foxy_sleeping.png', width: 104),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No sessions yet', style: text.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  'Go live, then your session summary will appear here.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
