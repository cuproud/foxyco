import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fox_settings.dart';
import '../../domain/offer_summary.dart';
import '../../domain/rate_mode.dart';
import '../settings/settings_controller.dart';
import '../theme/platform_badge.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// Full breakdown of one scored offer as a modal bottom sheet — opened by
/// tapping a History row or the Home "last offer" ticket. Shows every parsed
/// number plus the verdict math ("BAD because $0.68 < your $1.00 bar"), which
/// teaches the thresholds instead of leaving the verdict a black box.
void showOfferDetail(BuildContext context, OfferSummary offer) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _OfferDetailSheet(offer: offer),
  );
}

class _OfferDetailSheet extends ConsumerWidget {
  const _OfferDetailSheet({required this.offer});
  final OfferSummary offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = offer;
    final style = VerdictStyle.of(o.verdict);
    final settings = ref.watch(settingsProvider);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(o.seenAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

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
          // Grab handle.
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, color: style.color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm + Gap.xs),
              PlatformBadge(platform: o.platform, size: 20),
              const SizedBox(width: 6),
              Text(
                o.platform.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FoxColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          // Big fare.
          Text(
            '\$${o.payout.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 40,
              height: 1.0,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              color: FoxColors.cream,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Gap.md),
          // Stat grid: everything parsed. Unknowns (0) show an em-dash.
          Row(
            children: [
              _cell('\$${o.pricePerKm.toStringAsFixed(2)}', 'PER KM'),
              const SizedBox(width: Gap.sm),
              _cell(
                o.pricePerHour > 0
                    ? '\$${o.pricePerHour.toStringAsFixed(0)}'
                    : '—',
                'PER HOUR',
              ),
              const SizedBox(width: Gap.sm),
              _cell('${o.totalKm.toStringAsFixed(1)} km', 'TOTAL'),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              _cell(
                o.pickupKm > 0 ? '${o.pickupKm.toStringAsFixed(1)} km' : '—',
                'PICKUP',
              ),
              const SizedBox(width: Gap.sm),
              _cell(
                o.totalMinutes > 0 ? '${o.totalMinutes.round()} min' : '—',
                'TRIP TIME',
              ),
              const SizedBox(width: Gap.sm),
              _cell(
                o.pickupKm > 0 && o.totalKm > o.pickupKm
                    ? '${(o.totalKm - o.pickupKm).toStringAsFixed(1)} km'
                    : '—',
                'RIDE',
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          _VerdictMath(offer: o, settings: settings),
          // Inferred take/pass — presented as an estimate, not ground truth.
          if (o.outcome != OfferOutcome.unknown) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Icon(
                  o.outcome == OfferOutcome.taken
                      ? Icons.check_circle_outline_rounded
                      : Icons.highlight_off_rounded,
                  size: 15,
                  color: o.outcome == OfferOutcome.taken
                      ? VerdictColors.good
                      : FoxColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  o.outcome == OfferOutcome.taken
                      ? 'Likely taken'
                      : 'Likely passed',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
              style: TextStyle(
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

/// One plain-language line of why the verdict landed where it did, against
/// the driver's CURRENT thresholds (historic verdicts aren't re-scored — the
/// line says "your bar today" when the stored verdict disagrees).
class _VerdictMath extends StatelessWidget {
  const _VerdictMath({required this.offer, required this.settings});
  final OfferSummary offer;
  final FoxSettings settings;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(offer.verdict);
    final perHour = settings.rateMode == RateMode.perHour;
    final t = settings.activeThresholds;
    final rate = perHour ? offer.pricePerHour : offer.pricePerKm;
    final unit = perHour ? '/hr' : '/km';

    // No parsed time in per-hour mode → nothing to compare against.
    final String text;
    if (rate <= 0) {
      text = 'Not enough parsed data to score this one.';
    } else if (rate >= t.goodAtOrAbove) {
      text =
          '\$${rate.toStringAsFixed(2)}$unit clears your GOOD bar of '
          '\$${t.goodAtOrAbove.toStringAsFixed(2)}$unit.';
    } else if (rate < t.badBelow) {
      text =
          '\$${rate.toStringAsFixed(2)}$unit is under your BAD line of '
          '\$${t.badBelow.toStringAsFixed(2)}$unit.';
    } else {
      text =
          '\$${rate.toStringAsFixed(2)}$unit sits between your BAD '
          '\$${t.badBelow.toStringAsFixed(2)} and GOOD '
          '\$${t.goodAtOrAbove.toStringAsFixed(2)}$unit.';
    }

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.cardSm),
        border: Border.all(color: style.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.color, size: 18),
          const SizedBox(width: Gap.sm + Gap.xs),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: FoxColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
