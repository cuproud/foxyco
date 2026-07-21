import 'package:flutter/material.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../theme/tokens.dart';

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

class _ShiftRecapSheet extends StatelessWidget {
  const _ShiftRecapSheet({required this.stats, required this.duration});

  final OfferStats stats;
  final Duration duration;

  static String _durationLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  static String _hourLabel(int h) {
    final ampm = h < 12 ? 'AM' : 'PM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display $ampm';
  }

  @override
  Widget build(BuildContext context) {
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
        gradient: const LinearGradient(
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
              Text(
                'Shift recap 🌮',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                _durationLabel(duration),
                style: const TextStyle(
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
                  style: const TextStyle(
                    fontFamily: FoxFonts.display,
                    fontSize: 44,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                    color: FoxColors.cream,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const TextSpan(
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
          Row(
            children: [
              _pill(VerdictColors.good, s.good, 'good'),
              const SizedBox(width: Gap.sm),
              _pill(VerdictColors.ok, s.ok, 'ok'),
              const SizedBox(width: Gap.sm),
              _pill(VerdictColors.bad, s.bad, 'bad'),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              _cell(
                s.best != null && s.best!.pricePerKm > 0
                    ? '\$${s.best!.pricePerKm.toStringAsFixed(2)}'
                    : '—',
                'BEST \$/KM',
              ),
              const SizedBox(width: Gap.sm),
              _cell(
                s.goodAvgPerKm > 0
                    ? '\$${s.goodAvgPerKm.toStringAsFixed(2)}'
                    : '—',
                'GOOD AVG',
              ),
              const SizedBox(width: Gap.sm),
              _cell(
                s.busiestHour != null ? _hourLabel(s.busiestHour!) : '—',
                'BUSIEST',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(Color color, int count, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Text.rich(
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
      ),
    ),
  );

  Widget _cell(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: FoxFonts.display,
                fontSize: 16,
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
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: FoxColors.textDisabled,
            ),
          ),
        ],
      ),
    ),
  );
}
