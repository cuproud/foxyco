import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../settings/settings_controller.dart';
import '../theme/tokens.dart';
import 'recap_widgets.dart';

/// End-of-shift recap, shown when the driver slides to stop. Rolls up the
/// offers seen since going live: duration, count, split, best $/km, busiest
/// hour. Skipped entirely when the session saw no offers — a "0 offers"
/// recap is noise, not a reward.
void maybeShowShiftRecap(
  BuildContext context, {
  required DateTime? liveSince,
  required List<OfferSummary> allOffers,
}) {
  if (liveSince == null) return;
  final offers = allOffers.where((o) => !o.seenAt.isBefore(liveSince)).toList();
  if (offers.isEmpty) return;
  final duration = DateTime.now().difference(liveSince);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ShiftRecapSheet(stats: OfferStats.from(offers), duration: duration),
  );
}

class _ShiftRecapSheet extends ConsumerWidget {
  const _ShiftRecapSheet({required this.stats, required this.duration});

  final OfferStats stats;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = stats;
    return Container(
      margin: const EdgeInsets.all(Gap.sm),
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.md,
        Gap.lg,
        Gap.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: FoxColors.border),
        boxShadow: Shadows.hero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FoxColors.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Image.asset(
                'assets/branding/foxyco_head.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Text(
                  'Shift recap 🌮',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                durationLabel(duration),
                style: TextStyle(
                  fontFamily: FoxFonts.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.cream,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          // Headline: offers seen this session.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${s.total}',
                  style: TextStyle(
                    fontFamily: FoxFonts.display,
                    fontSize: 44,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                    color: FoxColors.cream,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: '  offers scored',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm + Gap.xs),
          // Verdict split, colored.
          VerdictSplitPills(good: s.good, ok: s.ok, bad: s.bad),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              StatTile(
                value: s.best != null && s.best!.pricePerKm > 0
                    ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(s.best!.pricePerKm).toStringAsFixed(2)}'
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
                value: s.busiestHour != null ? hourLabel(s.busiestHour!) : '—',
                label: 'BUSIEST',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
