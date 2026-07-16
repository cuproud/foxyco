import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/fox_settings.dart';
import '../../domain/overlay_payload.dart' show PillSize;
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'settings_controller.dart';

/// Settings — every driver-tunable knob in [FoxSettings]: verdict thresholds
/// (with live preview), pickup-distance guard, watched apps, pill size, and
/// history retention / clear. Styled to the cream/paper direction.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Slider ranges per rate mode ($/km vs $/hr scales differ ~20×).
  static const _minKm = 0.5;
  static const _maxKm = 3.0;
  static const _minHr = 10.0;
  static const _maxHr = 60.0;
  static const _engine = DecisionEngine();

  /// Live-preview sample rate, one per mode so flipping modes lands on a
  /// sensible sample instead of an out-of-range one.
  double _samplePpk = 1.25;
  double _samplePph = 25.0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final perHour = settings.rateMode == RateMode.perHour;
    final t = settings.activeThresholds;
    final min = perHour ? _minHr : _minKm;
    final max = perHour ? _maxHr : _maxKm;
    final unit = perHour ? '/hr' : '/km';
    final sample = perHour ? _samplePph : _samplePpk;
    final controller = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 100),
      children: [
        Row(
          children: [
            Text('Settings', style: text.headlineMedium),
            const Spacer(),
            TextButton(
              onPressed: controller.reset,
              style: TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              child: const Text('Reset',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        const _SectionLabel('Verdict thresholds'),
        const SizedBox(height: Gap.sm),
        Text(
          perHour
              ? 'FoxyCo scores every offer by dollars per hour. '
                  'Set where GOOD and BAD begin.'
              : 'FoxyCo scores every offer by dollars per kilometre. '
                  'Set where GOOD and BAD begin.',
          style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.md),
        // Rate mode — each mode keeps its own cut points. Offers with no
        // parsed time fall back to $/km scoring (engine fail-safe).
        Center(
          child: SegmentedButton<RateMode>(
            segments: [
              for (final m in RateMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {settings.rateMode},
            onSelectionChanged: (s) => controller.setRateMode(s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: FoxColors.brandFoxSoft,
              selectedForegroundColor: FoxColors.brandFoxDeep,
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        _Card(
          child: Column(
            children: [
              _ThresholdBand(thresholds: t, min: min, max: max),
              const SizedBox(height: Gap.lg),
              _ThresholdSlider(
                label: 'GOOD at or above',
                color: VerdictColors.good,
                value: t.goodAtOrAbove,
                min: min,
                max: max,
                onChanged: controller.setGood,
              ),
              const SizedBox(height: Gap.md),
              _ThresholdSlider(
                label: 'BAD below',
                color: VerdictColors.bad,
                value: t.badBelow,
                min: min,
                max: max,
                onChanged: controller.setBad,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        const _SectionLabel('Live preview'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _PreviewCard(
          sample: sample,
          unit: unit,
          verdict: _engine.evaluate(sample, t),
          min: min,
          max: max,
          onChanged: (v) => setState(() {
            if (perHour) {
              _samplePph = v;
            } else {
              _samplePpk = v;
            }
          }),
        ),
        const SizedBox(height: Gap.xl),
        const _SectionLabel('Pickup guard'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Card(
          child: _ThresholdSlider(
            label: 'Near pickup at or under',
            color: FoxColors.brandFox,
            value: settings.pickupNearKm,
            min: 0.5,
            max: 10.0,
            unit: 'km',
            onChanged: controller.setPickupNearKm,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Pickups under this distance show green on the pill; '
          'longer dead runs show red.',
          style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.xl),
        const _SectionLabel('Watched apps'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Card(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final app in GigPlatform.values) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.label, style: text.titleMedium),
                    value: settings.watches(app),
                    activeTrackColor: FoxColors.brandFox,
                    onChanged: (_) => controller.toggleApp(app),
                  ),
                  if (app != GigPlatform.values.last)
                    const Divider(color: FoxColors.border, height: 1),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xl),
        const _SectionLabel('Pill size'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Card(
          child: _ChoiceRow<PillSize>(
            values: PillSize.values,
            selected: settings.pillSize,
            labelOf: (s) => switch (s) {
              PillSize.small => 'Small',
              PillSize.medium => 'Medium',
              PillSize.large => 'Large',
            },
            onChanged: controller.setPillSize,
          ),
        ),
        const SizedBox(height: Gap.xl),
        const _SectionLabel('History'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keep offers for', style: text.titleMedium),
              const SizedBox(height: Gap.sm),
              _ChoiceRow<int>(
                values: const [7, 30, 90, FoxSettings.keepForever],
                selected: settings.retentionDays,
                labelOf: (d) =>
                    d == FoxSettings.keepForever ? 'Forever' : '$d days',
                onChanged: (d) {
                  controller.setRetentionDays(d);
                  if (d != FoxSettings.keepForever) {
                    ref.read(offerLogProvider.notifier).purgeOlderThan(d);
                  }
                },
              ),
              const Divider(color: FoxColors.border, height: Gap.xl),
              Center(
                child: TextButton(
                  onPressed: () => _confirmClear(context),
                  style: TextButton.styleFrom(
                      foregroundColor: VerdictColors.bad),
                  child: const Text('Clear offer history',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear offer history?'),
        content: const Text(
            'Every logged offer is deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes == true) ref.read(offerLogProvider.notifier).clearAll();
  }
}

/// Pill-shaped single-select row (pill size, retention).
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: Motion.base,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: v == selected ? FoxColors.ink : FoxColors.bgSurface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color:
                        v == selected ? FoxColors.ink : FoxColors.borderSoft,
                  ),
                ),
                child: Center(
                  child: Text(
                    labelOf(v),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: v == selected
                          ? FoxColors.cream
                          : FoxColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: Gap.sm),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md + Gap.xs),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: child,
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

/// A horizontal bar split into BAD / OK / GOOD zones at the current cut points.
class _ThresholdBand extends StatelessWidget {
  const _ThresholdBand({
    required this.thresholds,
    required this.min,
    required this.max,
  });

  final Thresholds thresholds;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final span = max - min;
    final badFlex = ((thresholds.badBelow - min) / span * 1000).round();
    final goodFlex = ((max - thresholds.goodAtOrAbove) / span * 1000).round();
    final okFlex = (1000 - badFlex - goodFlex).clamp(0, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (badFlex > 0)
                  Expanded(
                      flex: badFlex,
                      child: const ColoredBox(color: VerdictColors.bad)),
                if (okFlex > 0)
                  Expanded(
                      flex: okFlex,
                      child: const ColoredBox(color: VerdictColors.ok)),
                if (goodFlex > 0)
                  Expanded(
                      flex: goodFlex,
                      child: const ColoredBox(color: VerdictColors.good)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\$${min.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.labelSmall),
            Text('\$${max.toStringAsFixed(2)}/km',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
  });

  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Empty = dollars ('$1.50'); otherwise suffixed ('2.0 km').
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(label, style: text.titleMedium)),
            Text(
              unit.isEmpty
                  ? '\$${value.toStringAsFixed(2)}'
                  : '${value.toStringAsFixed(1)} $unit',
              style: text.titleMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            inactiveTrackColor: FoxColors.border,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 0.05).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Drag a sample offer's $/km and watch the verdict flip in real time.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.sample,
    required this.unit,
    required this.verdict,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double sample;
  final String unit; // '/km' or '/hr'
  final Verdict verdict;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(verdict);
    final text = Theme.of(context).textTheme;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, color: style.color, size: 20),
                    const SizedBox(width: Gap.sm),
                    Text(
                      style.label,
                      style: text.titleLarge?.copyWith(color: style.color),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '\$${sample.toStringAsFixed(2)}$unit',
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'A sample offer at this rate',
            style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: style.color,
              thumbColor: style.color,
              overlayColor: style.color.withValues(alpha: 0.15),
              inactiveTrackColor: FoxColors.border,
            ),
            child: Slider(
              value: sample,
              min: min,
              max: max,
              divisions: ((max - min) / 0.05).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
