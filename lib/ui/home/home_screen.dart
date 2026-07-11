import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/offer_summary.dart';
import '../overlay/overlay_controller.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';

/// Home dashboard (docs/UI_DESIGN §5.2).
///
/// The status card is the hero — the driver's #1 question is "is it actually
/// on?". Below it: permission chips, today's tally, and the last scored offer.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoxyCo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            _StatusCard(
              status: state.status,
              permissions: state.permissions,
              platforms: state.activePlatforms
                  .map((p) => p.label)
                  .join(' · '),
              onTogglePause: () =>
                  ref.read(dashboardProvider.notifier).togglePause(),
            ),
            const SizedBox(height: Gap.lg),
            const _SectionHeader('Permissions'),
            const SizedBox(height: Gap.sm),
            _PermissionChips(permissions: state.permissions),
            const SizedBox(height: Gap.lg),
            const _SectionHeader('Today'),
            const SizedBox(height: Gap.sm),
            _TallyRow(tally: state.today),
            const SizedBox(height: Gap.lg),
            const _SectionHeader('Last offer'),
            const SizedBox(height: Gap.sm),
            _LastOfferCard(offer: state.lastOffer),
            const SizedBox(height: Gap.lg),
            const _DebugOverlayCard(),
          ],
        ),
      ),
    );
  }
}

/// M2 dev tool: push a fake offer to the overlay so we can eyeball the pill over
/// another app without a real parser (M3) yet. Removed before release.
class _DebugOverlayCard extends ConsumerWidget {
  const _DebugOverlayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report_outlined,
                    size: 18, color: FoxColors.textSecondary),
                const SizedBox(width: Gap.sm),
                Text('Debug', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Show a fake verdict pill over other apps.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: FoxColors.textSecondary),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Simulate offer'),
                    onPressed: () => _simulate(context, ref),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(overlayControllerProvider.notifier).hide(),
                  child: const Text('Hide'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final shown = await ref
        .read(overlayControllerProvider.notifier)
        .simulateOffer();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(shown
            ? 'Pill shown — switch to another app to see it float.'
            : 'Grant "Display over other apps" to show the pill.'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

/// Hero card: is FoxyCo watching? Turns into a call-to-action if blocked.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.permissions,
    required this.platforms,
    required this.onTogglePause,
  });

  final WatchStatus status;
  final PermissionStatus permissions;
  final String platforms;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (dotColor, title) = switch (status) {
      WatchStatus.watching => (VerdictColors.good, 'Watching for offers'),
      WatchStatus.paused => (FoxColors.textDisabled, 'Paused'),
      WatchStatus.blocked => (VerdictColors.bad, 'Grant access to start'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(color: dotColor, live: status == WatchStatus.watching),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(title, style: text.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Padding(
              padding: const EdgeInsets.only(left: Gap.md + Gap.xs),
              child: Text(
                status == WatchStatus.blocked
                    ? 'Accessibility permission needed'
                    : platforms,
                style: text.bodyMedium?.copyWith(
                  color: FoxColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Align(
              alignment: Alignment.centerRight,
              child: status == WatchStatus.blocked
                  ? FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 44),
                      ),
                      child: const Text('Fix permissions'),
                    )
                  : OutlinedButton(
                      onPressed: onTogglePause,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 44),
                        foregroundColor: FoxColors.textPrimary,
                        side: const BorderSide(color: FoxColors.outline),
                      ),
                      child: Text(
                        status == WatchStatus.paused ? 'Resume' : 'Pause',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.live});
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: live
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _PermissionChips extends StatelessWidget {
  const _PermissionChips({required this.permissions});
  final PermissionStatus permissions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PermChip(
            label: 'Overlay',
            granted: permissions.overlayGranted,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _PermChip(
            label: 'Access',
            granted: permissions.accessibilityGranted,
          ),
        ),
      ],
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip({required this.label, required this.granted});
  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final color = granted ? VerdictColors.good : VerdictColors.bad;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm + Gap.xs,
      ),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: FoxColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: Gap.sm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  const _TallyRow({required this.tally});
  final Tally tally;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TallyCard(
            count: tally.good,
            label: 'GOOD',
            color: VerdictColors.good,
            empty: tally.isEmpty,
          ),
        ),
        const SizedBox(width: Gap.sm + Gap.xs),
        Expanded(
          child: _TallyCard(
            count: tally.ok,
            label: 'OK',
            color: VerdictColors.ok,
            empty: tally.isEmpty,
          ),
        ),
        const SizedBox(width: Gap.sm + Gap.xs),
        Expanded(
          child: _TallyCard(
            count: tally.bad,
            label: 'BAD',
            color: VerdictColors.bad,
            empty: tally.isEmpty,
          ),
        ),
      ],
    );
  }
}

class _TallyCard extends StatelessWidget {
  const _TallyCard({
    required this.count,
    required this.label,
    required this.color,
    required this.empty,
  });

  final int count;
  final String label;
  final Color color;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Column(
          children: [
            Text(
              empty ? '—' : '$count',
              style: text.headlineMedium?.copyWith(color: FoxColors.textPrimary),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              label,
              style: text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Most recent scored offer, or a friendly empty state.
class _LastOfferCard extends StatelessWidget {
  const _LastOfferCard({required this.offer});
  final OfferSummary? offer;

  @override
  Widget build(BuildContext context) {
    if (offer == null) {
      return const _EmptyOffers();
    }

    final text = Theme.of(context).textTheme;
    final style = VerdictStyle.of(offer!.verdict);
    final money = '\$${offer!.payout.toStringAsFixed(offer!.payout == offer!.payout.roundToDouble() ? 0 : 2)}';
    final ppk = '\$${offer!.pricePerKm.toStringAsFixed(2)}/km';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(style.icon, size: 16, color: style.color),
                const SizedBox(width: Gap.sm),
                Text(
                  style.label,
                  style: text.titleMedium?.copyWith(color: style.color),
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  offer!.platform.label,
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              '${offer!.totalKm.toStringAsFixed(1)} km · $money · $ppk',
              style: text.bodyMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              _relativeTime(offer!.seenAt),
              style: text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime when) {
    // Simple absolute time for MVP; a live "N min ago" needs a clock source
    // (kept deterministic for now — see dashboard_controller).
    final h = when.hour.toString().padLeft(2, '0');
    final m = when.minute.toString().padLeft(2, '0');
    return 'Today $h:$m';
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: Image.asset(
                'assets/branding/foxyco_icon_car_b.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'No offers yet',
              style: text.titleMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              "Open Uber or Hopp and drive — I'll start scoring.",
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
