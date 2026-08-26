import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../services/offer_log.dart';
import '../../services/session_log.dart';
import '../settings/settings_controller.dart';
import '../theme/platform_badge.dart';
import '../theme/outcome_style.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// Full breakdown of one scored offer as a modal bottom sheet — opened by
/// tapping a History row or the Home "last offer" ticket. Shows every parsed
/// number in a compact, scannable layout.
void showOfferDetail(BuildContext context, OfferSummary offer) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // Scroll-controlled: the default sheet caps at 9/16 of the screen and this
    // card is taller than that at large text scales, so the top of the content
    // was being cut off (device 2026-07-26).
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _OfferDetailSheet(offer: offer),
  );
}

class _OfferDetailSheet extends ConsumerWidget {
  const _OfferDetailSheet({required this.offer});
  final OfferSummary offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref
        .watch(offerLogProvider)
        .where(
          (candidate) =>
              candidate.seenAt == offer.seenAt && candidate.sameCardAs(offer),
        )
        .firstOrNull;
    final current = o ?? offer;
    final style = VerdictStyle.of(current.verdict);
    final outcome = OutcomeStyle.of(current.outcome);
    final settings = ref.watch(settingsProvider);
    final snapshot = current.scoringSnapshot;
    final currency = snapshot?.currency ?? settings.currency;
    final distanceUnit = snapshot?.distanceUnit ?? settings.distanceUnit;
    final canEditFinalPayout =
        current.outcome == OfferOutcome.taken ||
        current.outcome == OfferOutcome.completed ||
        current.finalPayout != null;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(current.seenAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    return Container(
      margin: const EdgeInsets.all(Gap.sm),
      clipBehavior: Clip.antiAlias,
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
        children: [
          // Grab handle, outside the scroll view so it stays put.
          Padding(
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FoxColors.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.lg + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: verdict, who it came from, when. The pill + platform
                  // group scales down together rather than pushing the time off
                  // the card at large text scales; the ride category used to be
                  // crammed in here too and came out as "Ube…", so it has its
                  // own line under the fare now (device 2026-07-26).
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                    Icon(
                                      style.icon,
                                      color: style.color,
                                      size: 16,
                                    ),
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
                              PlatformBadge(
                                platform: current.platform,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                current.platform.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: FoxColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: FoxColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  // Big fare. scaleDown so a four-figure fare — or a 2× text
                  // scale — shrinks instead of running off the card.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${currency.prefix}${current.effectivePayout.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 40,
                        // 1.0 shaved the display font's ascenders.
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: FoxColors.cream,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.finalPayout == null
                              ? 'Upfront offer'
                              : 'Final earnings · upfront ${currency.prefix}${current.payout.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FoxColors.textSecondary,
                          ),
                        ),
                      ),
                      if (canEditFinalPayout)
                        OutlinedButton.icon(
                          onPressed: () => _editFinalPayout(
                            context,
                            ref,
                            current,
                            currency.prefix,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 15),
                          label: Text(
                            current.finalPayout == null ? 'Add final' : 'Edit',
                          ),
                        ),
                    ],
                  ),
                  if (current.category != null)
                    Text(
                      current.category!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  if (current.itemCount > 0) ...[
                    const SizedBox(height: Gap.xs),
                    Text(
                      '${current.itemCount} items'
                      '${current.unitCount > 0 ? ' · ${current.unitCount} units' : ''}'
                      '${current.deliveryCount > 1 ? ' · ${current.deliveryCount} orders' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                  if (current.bonus > 0) ...[
                    const SizedBox(height: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: VerdictColors.good.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(
                          color: VerdictColors.good.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            size: 15,
                            color: VerdictColors.good,
                          ),
                          const SizedBox(width: Gap.xs),
                          Text(
                            'Includes ${currency.prefix}${current.bonus.toStringAsFixed(2)} bonus',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: VerdictColors.good,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          icon: Icons.trending_up_rounded,
                          value:
                              '${currency.prefix}${distanceUnit.rateFromPerKm(current.effectivePricePerKm).toStringAsFixed(2)}',
                          label: 'PER ${distanceUnit.shortLabel.toUpperCase()}',
                          color: style.color,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: _DetailMetric(
                          icon: Icons.star_outline_rounded,
                          value: current.effectivePricePerHour > 0
                              ? '${currency.prefix}${current.effectivePricePerHour.toStringAsFixed(2)}'
                              : '—',
                          label: 'PER HOUR',
                          color: style.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  _DetailBand(
                    leftIcon: Icons.route_rounded,
                    leftValue:
                        '${distanceUnit.distanceFromKm(current.totalKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}',
                    leftLabel: 'TOTAL DISTANCE',
                    rightIcon: Icons.schedule_rounded,
                    rightValue: current.totalMinutes > 0
                        ? '${current.totalMinutes.round()} min'
                        : '—',
                    rightLabel: 'TOTAL TIME',
                  ),
                  const SizedBox(height: Gap.sm),
                  _DetailBand(
                    leftIcon: Icons.location_on_outlined,
                    leftValue: current.pickupKm > 0
                        ? '${distanceUnit.distanceFromKm(current.pickupKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}'
                        : '—',
                    leftLabel: 'PICKUP',
                    rightIcon: Icons.flag_outlined,
                    rightValue:
                        current.pickupKm > 0 &&
                            current.totalKm > current.pickupKm
                        ? '${distanceUnit.distanceFromKm(current.totalKm - current.pickupKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}'
                        : '—',
                    rightLabel: 'RIDE',
                  ),
                  const SizedBox(height: Gap.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: outcome.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.field),
                      border: Border.all(
                        color: outcome.color.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(outcome.icon, size: 20, color: outcome.color),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                outcome.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: outcome.color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                outcome.detail,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.3,
                                  color: FoxColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: FoxColors.textSecondary,
                      ),
                      const SizedBox(width: Gap.xs),
                      Expanded(
                        child: Text(
                          'Rates and distances may change until the trip is completed.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: FoxColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editFinalPayout(
    BuildContext context,
    WidgetRef ref,
    OfferSummary offer,
    String prefix,
  ) async {
    var input = offer.finalPayout?.toStringAsFixed(2) ?? '';
    String? error;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void save() {
            final parsed = double.tryParse(input.trim().replaceAll(',', '.'));
            if (parsed == null || !parsed.isFinite || parsed <= 0) {
              setState(() => error = 'Enter an amount above zero');
              return;
            }
            Navigator.pop(context, (parsed * 100).round() / 100);
          }

          return AlertDialog(
            title: const Text('Final earnings'),
            content: TextFormField(
              initialValue: input,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*(?:[.,]\d{0,2})?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              onChanged: (value) => input = value,
              onFieldSubmitted: (_) => save(),
              decoration: InputDecoration(
                prefixText: prefix,
                labelText: 'Amount received',
                helperText:
                    'Upfront offer: $prefix${offer.payout.toStringAsFixed(2)}',
                errorText: error,
              ),
            ),
            actions: [
              if (offer.finalPayout != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: VerdictColors.bad,
                  ),
                  onPressed: () => Navigator.pop(context, double.nan),
                  child: const Text('Remove'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: save, child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (value == null) return;
    final changed = ref
        .read(offerLogProvider.notifier)
        .setFinalPayout(offer, value.isNaN ? null : value);
    if (changed) {
      await ref
          .read(sessionLogProvider.notifier)
          .refreshForOffer(offer, ref.read(offerLogProvider));
    }
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 108),
    padding: const EdgeInsets.all(Gap.sm),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(Radii.cardSm),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: Gap.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: FoxColors.textDisabled,
          ),
        ),
      ],
    ),
  );
}

class _DetailBand extends StatelessWidget {
  const _DetailBand({
    required this.leftIcon,
    required this.leftValue,
    required this.leftLabel,
    required this.rightIcon,
    required this.rightValue,
    required this.rightLabel,
  });

  final IconData leftIcon;
  final String leftValue;
  final String leftLabel;
  final IconData rightIcon;
  final String rightValue;
  final String rightLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
    decoration: BoxDecoration(
      color: FoxColors.bgSurface2.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(Radii.cardSm),
      border: Border.all(color: FoxColors.borderSoft),
    ),
    child: Row(
      children: [
        Expanded(
          child: _DetailBandItem(
            icon: leftIcon,
            value: leftValue,
            label: leftLabel,
          ),
        ),
        Container(width: 1, height: 44, color: FoxColors.border),
        Expanded(
          child: _DetailBandItem(
            icon: rightIcon,
            value: rightValue,
            label: rightLabel,
          ),
        ),
      ],
    ),
  );
}

class _DetailBandItem extends StatelessWidget {
  const _DetailBandItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 28,
        child: Center(child: Icon(icon, size: 20, color: FoxColors.brandFox)),
      ),
      const SizedBox(width: Gap.sm),
      Flexible(
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
                  fontWeight: FontWeight.w700,
                  color: FoxColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: FoxColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
