import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../../domain/fox_settings.dart';
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
    builder: (_) => _ShiftRecapSheet(offers: offers, duration: duration),
  );
}

class _ShiftRecapSheet extends ConsumerWidget {
  const _ShiftRecapSheet({required this.offers, required this.duration});

  final List<OfferSummary> offers;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = OfferStats.from(offers);
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
                  'Shift recap',
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
          _RecapVolume(total: s.total, accepted: s.accepted),
          const SizedBox(height: Gap.sm + Gap.xs),
          // Verdict split, colored.
          VerdictSplitPills(good: s.good, ok: s.ok, bad: s.bad),
          const SizedBox(height: Gap.sm),
          _RecapEarnings(
            offers: offers,
            duration: duration,
            settings: settings,
          ),
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

class _RecapVolume extends StatelessWidget {
  const _RecapVolume({required this.total, required this.accepted});

  final int total;
  final int accepted;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: _metric(
          '$total',
          total == 1 ? 'offer scored' : 'offers scored',
          36,
        ),
      ),
      const SizedBox(width: Gap.lg),
      Expanded(child: _metric('$accepted', 'accepted', 28, accepted: true)),
    ],
  );

  Widget _metric(
    String value,
    String label,
    double size, {
    bool accepted = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accepted) ...[
            Icon(
              Icons.check_circle_outline,
              color: VerdictColors.good,
              size: 16,
            ),
            const SizedBox(width: Gap.xs),
          ],
          Text(
            value,
            style: TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: size,
              height: 1,
              fontWeight: FontWeight.w700,
              color: FoxColors.cream,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: accepted ? VerdictColors.good : FoxColors.textSecondary,
        ),
      ),
    ],
  );
}

class _RecapEarnings extends StatelessWidget {
  const _RecapEarnings({
    required this.offers,
    required this.duration,
    required this.settings,
  });
  final List<OfferSummary> offers;
  final Duration duration;
  final FoxSettings settings;

  @override
  Widget build(BuildContext context) {
    // Accepted offers are the best available earnings estimate until the
    // driver marks them completed or enters final earnings.
    final completed = offers
        .where(
          (offer) =>
              offer.outcome == OfferOutcome.taken ||
              offer.outcome == OfferOutcome.completed,
        )
        .fold(0.0, (sum, offer) => sum + offer.effectivePayout);
    final earnings = completed > 0
        ? '${settings.currency.prefix}${completed.toStringAsFixed(2)}'
        : '—';
    final hourly = completed > 0 && duration.inMinutes > 0
        ? '${settings.currency.prefix}${(completed / (duration.inMinutes / 60)).toStringAsFixed(0)}/hr'
        : '—/hr';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _metric(
            'Estimated earnings',
            earnings,
            'Accepted and completed offers',
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: _metric('Session rate', hourly, 'Completed offers only'),
        ),
      ],
    );
  }

  Widget _metric(String title, String value, String support) => Column(
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
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: FoxFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: FoxColors.cream,
          fontFeatures: [FontFeature.tabularFigures()],
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
