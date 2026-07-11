import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'settings_controller.dart';

/// Settings (docs/UI_DESIGN §5.3, M1).
///
/// The whole screen is the driver's one tunable surface: the two $/km cut points
/// that decide GOOD/OK/BAD. A live preview shows exactly how a sample offer would
/// be scored as they drag — no guessing, no separate "test" trip.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Slider bounds for the whole screen. $/km rarely lives outside this band.
  static const _min = 0.5;
  static const _max = 3.0;

  static const _engine = DecisionEngine();

  /// The preview offer the driver drags to "feel" their thresholds. Starts mid.
  double _samplePpk = 1.25;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => controller.reset(),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            const _SectionHeader('Verdict thresholds'),
            const SizedBox(height: Gap.sm),
            Text(
              'FoxyCo scores every offer by dollars per kilometre. '
              'Set where GOOD and BAD begin.',
              style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
            ),
            const SizedBox(height: Gap.lg),

            _ThresholdBand(thresholds: t, min: _min, max: _max),
            const SizedBox(height: Gap.lg),

            _ThresholdSlider(
              label: 'GOOD at or above',
              color: VerdictColors.good,
              value: t.goodAtOrAbove,
              min: _min,
              max: _max,
              onChanged: controller.setGood,
            ),
            const SizedBox(height: Gap.md),
            _ThresholdSlider(
              label: 'BAD below',
              color: VerdictColors.bad,
              value: t.badBelow,
              min: _min,
              max: _max,
              onChanged: controller.setBad,
            ),

            const SizedBox(height: Gap.xl),
            const _SectionHeader('Live preview'),
            const SizedBox(height: Gap.sm),
            _PreviewCard(
              samplePpk: _samplePpk,
              verdict: _engine.evaluate(_samplePpk, t),
              min: _min,
              max: _max,
              onChanged: (v) => setState(() => _samplePpk = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

/// A horizontal bar split into BAD / OK / GOOD zones at the current cut points.
/// Makes the abstract numbers concrete: you see the band, not just two figures.
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
          borderRadius: BorderRadius.circular(Radii.field),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (badFlex > 0)
                  Expanded(flex: badFlex, child: const ColoredBox(color: VerdictColors.bad)),
                if (okFlex > 0)
                  Expanded(flex: okFlex, child: const ColoredBox(color: VerdictColors.ok)),
                if (goodFlex > 0)
                  Expanded(flex: goodFlex, child: const ColoredBox(color: VerdictColors.good)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
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
  });

  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

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
              '\$${value.toStringAsFixed(2)}',
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
            inactiveTrackColor: FoxColors.outline,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            // 5¢ steps — fine enough to tune, coarse enough to hit with a thumb.
            divisions: ((max - min) / 0.05).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Drag a sample offer's $/km and watch the verdict flip in real time — the
/// same [DecisionEngine] the overlay will run, so what you see is what you'll get.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.samplePpk,
    required this.verdict,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double samplePpk;
  final Verdict verdict;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(verdict);
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(style.icon, color: style.color, size: 28),
                const SizedBox(width: Gap.sm),
                Text(
                  style.label,
                  style: text.headlineMedium?.copyWith(color: style.color),
                ),
                const Spacer(),
                Text(
                  '\$${samplePpk.toStringAsFixed(2)}/km',
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
                inactiveTrackColor: FoxColors.outline,
              ),
              child: Slider(
                value: samplePpk,
                min: min,
                max: max,
                divisions: ((max - min) / 0.05).round(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
