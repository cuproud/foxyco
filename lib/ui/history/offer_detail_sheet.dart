import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../domain/rate_mode.dart';
import '../../services/offer_log.dart';
import '../../services/session_log.dart';
import '../settings/settings_controller.dart';
import '../theme/platform_badge.dart';
import '../theme/outcome_style.dart';
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
                        TextButton.icon(
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
                      child: Text(
                        'Includes ${currency.prefix}${current.bonus.toStringAsFixed(2)} bonus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: VerdictColors.good,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                  // Stat grid: everything parsed. Unknowns (0) show an em-dash.
                  Row(
                    children: [
                      _cell(
                        '${currency.prefix}${distanceUnit.rateFromPerKm(current.effectivePricePerKm).toStringAsFixed(2)}',
                        'PER ${distanceUnit.shortLabel.toUpperCase()}',
                        style.color,
                      ),
                      const SizedBox(width: Gap.sm),
                      _cell(
                        current.effectivePricePerHour > 0
                            ? '${settings.currency.prefix}${current.effectivePricePerHour.toStringAsFixed(0)}'
                            : '—',
                        'PER HOUR',
                        style.color,
                      ),
                      const SizedBox(width: Gap.sm),
                      _cell(
                        '${distanceUnit.distanceFromKm(current.totalKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}',
                        'TOTAL',
                        style.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      _cell(
                        current.pickupKm > 0
                            ? '${distanceUnit.distanceFromKm(current.pickupKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}'
                            : '—',
                        'PICKUP',
                        style.color,
                      ),
                      const SizedBox(width: Gap.sm),
                      _cell(
                        current.totalMinutes > 0
                            ? '${current.totalMinutes.round()} min'
                            : '—',
                        'TOTAL TIME',
                        style.color,
                      ),
                      const SizedBox(width: Gap.sm),
                      _cell(
                        current.pickupKm > 0 &&
                                current.totalKm > current.pickupKm
                            ? '${distanceUnit.distanceFromKm(current.totalKm - current.pickupKm).toStringAsFixed(1)} ${distanceUnit.shortLabel}'
                            : '—',
                        'RIDE',
                        style.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  _VerdictMath(offer: current),
                  const SizedBox(height: Gap.sm),
                  Container(
                    padding: const EdgeInsets.all(12),
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

  Widget _cell(String value, String label, Color verdictColor) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: verdictColor.withValues(alpha: 0.22)),
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
            style: TextStyle(
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

/// One plain-language line of why the verdict landed where it did, using the
/// scoring snapshot captured with the offer. Legacy rows without a snapshot
/// are identified as such instead of being explained with today's Rules.
class _VerdictMath extends StatelessWidget {
  const _VerdictMath({required this.offer});
  final OfferSummary offer;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(offer.verdict);
    final snapshot = offer.scoringSnapshot;
    if (snapshot == null) {
      return _legacyBox(
        'Older offer · no saved scoring snapshot. Current Rules do not '
        'rewrite it.',
      );
    }
    final perHour = snapshot.rateMode == RateMode.perHour;
    final goodCanonical = perHour ? snapshot.goodPerHour : snapshot.goodPerKm;
    final badCanonical = perHour ? snapshot.badPerHour : snapshot.badPerKm;
    final rate = perHour
        ? offer.pricePerHour
        : snapshot.distanceUnit.rateFromPerKm(offer.pricePerKm);
    final good = perHour
        ? goodCanonical
        : snapshot.distanceUnit.rateFromPerKm(goodCanonical);
    final bad = perHour
        ? badCanonical
        : snapshot.distanceUnit.rateFromPerKm(badCanonical);
    final unit = perHour ? '/hr' : '/${snapshot.distanceUnit.shortLabel}';
    final prefix = snapshot.currency.prefix;

    // No parsed time in per-hour mode → nothing to compare against.
    String text;
    if (rate <= 0) {
      text = 'Not enough parsed data to score this one.';
    } else if (rate >= good) {
      text =
          '$prefix${rate.toStringAsFixed(2)}$unit clears your GOOD bar of '
          '$prefix${good.toStringAsFixed(2)}$unit.';
    } else if (rate < bad) {
      text =
          '$prefix${rate.toStringAsFixed(2)}$unit is under your BAD line of '
          '$prefix${bad.toStringAsFixed(2)}$unit.';
    } else {
      text =
          '$prefix${rate.toStringAsFixed(2)}$unit sits between your BAD '
          '$prefix${bad.toStringAsFixed(2)} and GOOD '
          '$prefix${good.toStringAsFixed(2)}$unit.';
    }

    if (snapshot.minimumPayoutEnabled &&
        offer.payout < snapshot.minimumPayout) {
      text =
          '$prefix${offer.payout.toStringAsFixed(2)} is below the saved '
          'minimum offer of $prefix${snapshot.minimumPayout.toStringAsFixed(2)}.';
    }
    return _box(style, text);
  }

  Widget _box(VerdictStyle style, String text) => Container(
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
            style: TextStyle(
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

  Widget _legacyBox(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
    decoration: BoxDecoration(
      color: FoxColors.bgSurface2.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(Radii.cardSm),
      border: Border.all(color: FoxColors.borderSoft),
    ),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: FoxColors.textSecondary,
          size: 16,
        ),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: FoxColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
