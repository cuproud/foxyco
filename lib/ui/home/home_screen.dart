import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../services/offer_log.dart';
import '../overlay/overlay_controller.dart';
import '../settings/settings_controller.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'profile_card.dart';
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
      // Bottom pad clears the floating nav (64 + margins).
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 100),
      children: [
        const _BrandBar(),
        const SizedBox(height: Gap.md),
        // Hidden (zero-height, incl. its own bottom pad) until a name is set.
        const ProfileCard(),
        _Hero(
          status: state.status,
          tally: ref.watch(todayTallyProvider),
          platforms: ref
              .watch(settingsProvider)
              .watchedApps
              .map((p) => p.label)
              .toList(),
          // Slide-to-go-live is the Start/Stop outer gate (spec M6 §3.2);
          // pause stays on the bubble long-press.
          onStart: controller.startMonitoring,
          onStop: controller.stopMonitoring,
          onFix: controller.requestMissingPermissions,
        ),
        const SizedBox(height: Gap.lg),
        if (blocked) ...[
          _AccessAlert(onFix: controller.requestMissingPermissions),
          const SizedBox(height: Gap.lg),
        ],
        const _SectionLabel('Last offer'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Ticket(offer: ref.watch(lastOfferProvider)),
        const SizedBox(height: Gap.md),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(overlayControllerProvider.notifier).simulateOffer(),
            child: Text(
              'Show a demo pill',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FoxColors.textDisabled,
                decoration: TextDecoration.underline,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Brand mark + name + a Live/Paused status pill.
class _BrandBar extends ConsumerWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused =
        ref.watch(dashboardProvider).status != WatchStatus.watching;
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/branding/foxyco_bubble.png',
            width: 30,
            height: 30,
          ),
        ),
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
    final color = paused ? FoxColors.textSecondary : VerdictColors.good;
    final bg = paused ? FoxColors.cream : VerdictColors.goodBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
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
    required this.platforms,
    required this.onStart,
    required this.onStop,
    required this.onFix,
  });

  final WatchStatus status;
  final Tally tally;
  final List<String> platforms;
  final VoidCallback onStart; // begin monitoring
  final VoidCallback onStop; // stop monitoring
  final VoidCallback onFix; // grant missing permission

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
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        boxShadow: Shadows.hero,
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
              for (final p in platforms) ...[
                _AppTag(p),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: Gap.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontFamily: FoxFonts.display,
                  fontSize: 56,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.5,
                  color: FoxColors.cream,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                'offers seen today',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  color: FoxColors.cream.withValues(alpha: 0.52),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md + Gap.xs),
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

class _AppTag extends StatelessWidget {
  const _AppTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: FoxColors.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FoxColors.cream.withValues(alpha: 0.68),
        ),
      ),
    );
  }
}

/// The proportional good/ok/bad bar inside the hero.
class _SegBar extends StatelessWidget {
  const _SegBar({required this.tally});
  final Tally tally;

  @override
  Widget build(BuildContext context) {
    // Empty tally -> no segments, and the container's tinted track shows through.
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        height: 12,
        color: FoxColors.cream.withValues(alpha: 0.10),
        child: Row(
          children: [
            if (tally.good > 0)
              Expanded(
                flex: tally.good,
                child: const ColoredBox(color: VerdictColors.goodOnDark),
              ),
            if (tally.ok > 0)
              Expanded(
                flex: tally.ok,
                child: const ColoredBox(color: VerdictColors.okOnDark),
              ),
            if (tally.bad > 0)
              Expanded(
                flex: tally.bad,
                child: const ColoredBox(color: VerdictColors.badOnDark),
              ),
          ],
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
    return Row(
      children: [
        _LegendItem(VerdictColors.goodOnDark, tally.good, 'good'),
        const SizedBox(width: Gap.md),
        _LegendItem(VerdictColors.okOnDark, tally.ok, 'ok'),
        const SizedBox(width: Gap.md),
        _LegendItem(VerdictColors.badOnDark, tally.bad, 'bad'),
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
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
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
              TextSpan(text: ' $label'),
            ],
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: FoxColors.cream.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
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
          const Icon(Icons.warning_amber_rounded,
              color: VerdictColors.bad, size: 22),
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
                    fontSize: 13, height: 1.4, color: FoxColors.textPrimary),
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
            child: const Text('Fix',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
        Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
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
    final time =
        '${o.seenAt.hour.toString().padLeft(2, '0')}:${o.seenAt.minute.toString().padLeft(2, '0')}';
    final fare = o.payout == o.payout.roundToDouble()
        ? '\$${o.payout.toStringAsFixed(0)}'
        : '\$${o.payout.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
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
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4.5),
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
            padding: const EdgeInsets.fromLTRB(21, 16, 21, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TicketStat('${o.totalKm.toStringAsFixed(1)} km', 'DISTANCE'),
                _TicketStat(fare, 'FARE'),
                _TicketStat('\$${o.pricePerKm.toStringAsFixed(2)}', 'PER KM'),
              ],
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: FoxFonts.display,
            fontSize: 18.5,
            fontWeight: FontWeight.w600,
            color: FoxColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: FoxColors.textDisabled,
          ),
        ),
      ],
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
          ClipOval(
            child: Image.asset('assets/branding/foxyco_bubble.png',
                width: 64, height: 64),
          ),
          const SizedBox(height: Gap.sm),
          Text('No offers yet', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            "Open Uber or Hopp and drive — I'll start scoring.",
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
