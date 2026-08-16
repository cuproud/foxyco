import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/car_reminder.dart';
import '../../domain/platform.dart';
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
        100 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        const _Padded(child: _BrandBar()),
        const SizedBox(height: Gap.sm),
        // Trial countdown / unlock ask / offline-check warning. Zero height when
        // there's nothing to say, which is the normal case.
        const _Padded(child: AccessBanner()),
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
            platforms: ref.watch(settingsProvider).watchedApps.toList(),
            // Slide-to-go-live is the Start/Stop outer gate (spec M6 §3.2);
            // pause stays on the bubble long-press.
            onStart: () => unawaited(controller.startMonitoring()),
            onStop: () {
              final since = controller.stopMonitoring();
              maybeShowShiftRecap(
                context,
                liveSince: since,
                allOffers: ref.read(offerLogProvider),
              );
            },
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
        const _Padded(child: SectionLabel('Fox tips')),
        const SizedBox(height: Gap.sm + Gap.xs),
        const _Padded(child: FoxTipsCard()),
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
      WatchStatus.blocked => 'Access needed',
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
                            color: FoxColors.textDisabled,
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
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${s.total}',
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 36,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: FoxColors.cream,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: s.total == 1 ? '  offer scored' : '  offers scored',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.total == 0) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  'Quiet one — nothing came in while the watcher ran.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: Gap.sm + Gap.xs),
                VerdictSplitPills(good: s.good, ok: s.ok, bad: s.bad),
                const SizedBox(height: Gap.sm + Gap.xs),
                Row(
                  children: [
                    StatTile(
                      value: s.bestPerKm > 0
                          ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(s.bestPerKm).toStringAsFixed(2)}'
                          : '—',
                      label:
                          'BEST \$/${settings.distanceUnit.shortLabel.toUpperCase()}',
                    ),
                    const SizedBox(width: Gap.sm),
                    StatTile(
                      value: s.goodAvgPerKm > 0
                          ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(s.goodAvgPerKm).toStringAsFixed(2)}'
                          : '—',
                      label: 'GOOD AVG',
                    ),
                    const SizedBox(width: Gap.sm),
                    StatTile(
                      value: s.busiestHour != null
                          ? hourLabel(s.busiestHour!)
                          : '—',
                      label: 'BUSIEST',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  const _EmptySession();

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
          // Foxy asleep on the grass: a landscape crop, so width only — forcing
          // it square would squash the fox.
          Image.asset('assets/branding/foxy_sleeping.png', width: 132),
          const SizedBox(height: Gap.sm),
          Text('No sessions yet 🍪', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            "Slide to go live — I'll recap the shift here when you stop.",
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
