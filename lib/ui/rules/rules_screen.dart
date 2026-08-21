import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/distance_unit.dart';
import '../../domain/offer.dart';
import '../../domain/overlay_payload.dart';
import '../../domain/platform.dart';
import '../../parser/parser_registry.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../domain/fox_settings.dart';
import '../../services/verdict_voice.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_controls.dart';
import '../overlay/verdict_pill.dart';
import '../shell/root_shell.dart';
import '../theme/platform_badge.dart';
import '../theme/section_label.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// The controls that decide how every offer is scored.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _PreviewOfferValues {
  const _PreviewOfferValues({
    required this.payout,
    required this.pickupDistanceKm,
    required this.pickupMinutes,
    required this.tripDistanceKm,
    required this.tripMinutes,
  });

  final double payout;
  final double pickupDistanceKm;
  final double pickupMinutes;
  final double tripDistanceKm;
  final double tripMinutes;

  double get pickupHours => (pickupMinutes ~/ 60).toDouble();
  double get pickupMinutePart => pickupMinutes % 60;
  double get tripHours => (tripMinutes ~/ 60).toDouble();
  double get tripMinutePart => tripMinutes % 60;
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  static const _minKm = 0.5;
  static const _maxKm = 3.0;
  static const _minHr = 10.0;
  static const _maxHr = 60.0;
  static const _engine = DecisionEngine();
  static const _hourPresets = [
    ('Relaxed', Thresholds(goodAtOrAbove: 26, badBelow: 18)),
    ('Balanced', Thresholds(goodAtOrAbove: 30, badBelow: 20)),
    ('Picky', Thresholds(goodAtOrAbove: 36, badBelow: 24)),
  ];

  static List<Color> get _accents => [
    VerdictColors.good,
    const Color(0xFF5EC2CD),
    const Color(0xFF4FA3E8),
    const Color(0xFFB48AE8),
    const Color(0xFFF0A24B),
    const Color(0xFF66A86F),
  ];

  double _samplePayout = 0;
  double _pickupDistanceKm = 0;
  double _pickupMinutes = 0;
  double _tripDistanceKm = 0;
  double _tripMinutes = 0;
  var _previewEdited = false;
  var _exampleStep = 0;
  final _random = math.Random();
  int _open = -1;
  final _rowKeys = List.generate(6, (_) => GlobalKey());
  late final TextEditingController _payoutController;
  late final TextEditingController _pickupDistanceController;
  late final TextEditingController _pickupHoursController;
  late final TextEditingController _pickupMinutesController;
  late final TextEditingController _tripDistanceController;
  late final TextEditingController _tripHoursController;
  late final TextEditingController _tripMinutesController;

  @override
  void initState() {
    super.initState();
    final initial = _exampleFor(ref.read(settingsProvider), Verdict.good);
    _payoutController = TextEditingController(
      text: initial.payout.toStringAsFixed(2),
    );
    _pickupDistanceController = TextEditingController(
      text: initial.pickupDistanceKm.toStringAsFixed(1),
    );
    _pickupHoursController = TextEditingController(
      text: initial.pickupHours.toStringAsFixed(0),
    );
    _pickupMinutesController = TextEditingController(
      text: initial.pickupMinutes.toStringAsFixed(0),
    );
    _tripDistanceController = TextEditingController(
      text: initial.tripDistanceKm.toStringAsFixed(1),
    );
    _tripHoursController = TextEditingController(
      text: initial.tripHours.toStringAsFixed(0),
    );
    _tripMinutesController = TextEditingController(
      text: initial.tripMinutes.toStringAsFixed(0),
    );
    _applyPreview(
      initial,
      distanceUnit: ref.read(settingsProvider).distanceUnit,
    );
  }

  @override
  void dispose() {
    _payoutController.dispose();
    _pickupDistanceController.dispose();
    _pickupHoursController.dispose();
    _pickupMinutesController.dispose();
    _tripDistanceController.dispose();
    _tripHoursController.dispose();
    _tripMinutesController.dispose();
    super.dispose();
  }

  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);

  Widget _previewField(
    String label,
    TextEditingController controller,
    ValueChanged<double> onValue, {
    String? suffix,
    String? prefix,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      isDense: true,
      labelStyle: const TextStyle(fontSize: 12),
      prefixStyle: const TextStyle(fontSize: 12),
      suffixStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    ),
    onChanged: (raw) {
      final value = double.tryParse(raw.trim().replaceAll(',', ''));
      if (value != null) onValue(value);
    },
  );

  void _applyPreview(
    _PreviewOfferValues value, {
    bool edited = false,
    DistanceUnit distanceUnit = DistanceUnit.kilometres,
  }) {
    _samplePayout = value.payout;
    _pickupDistanceKm = value.pickupDistanceKm;
    _pickupMinutes = value.pickupMinutes;
    _tripDistanceKm = value.tripDistanceKm;
    _tripMinutes = value.tripMinutes;
    _payoutController.text = value.payout.toStringAsFixed(2);
    _pickupDistanceController.text = distanceUnit
        .distanceFromKm(value.pickupDistanceKm)
        .toStringAsFixed(1);
    _pickupHoursController.text = value.pickupHours.toStringAsFixed(0);
    _pickupMinutesController.text = value.pickupMinutePart.toStringAsFixed(0);
    _tripDistanceController.text = distanceUnit
        .distanceFromKm(value.tripDistanceKm)
        .toStringAsFixed(1);
    _tripHoursController.text = value.tripHours.toStringAsFixed(0);
    _tripMinutesController.text = value.tripMinutePart.toStringAsFixed(0);
    _previewEdited = edited;
  }

  void _changePreview(void Function() change) {
    setState(() {
      _previewEdited = true;
      change();
    });
  }

  void _tryExample(FoxSettings settings) {
    final target = switch (_exampleStep++ % 3) {
      0 => Verdict.ok,
      1 => Verdict.bad,
      _ => Verdict.good,
    };
    final belowMinimum =
        target == Verdict.bad &&
        settings.minimumPayoutEnabled &&
        settings.minimumPayout > 0 &&
        _exampleStep.isEven;
    _applyPreview(
      _exampleFor(
        settings,
        target,
        belowMinimum: belowMinimum,
        pickupNear: _random.nextBool(),
      ),
      distanceUnit: settings.distanceUnit,
    );
    setState(() {});
  }

  _PreviewOfferValues _exampleFor(
    FoxSettings settings,
    Verdict target, {
    bool belowMinimum = false,
    bool? pickupNear,
  }) {
    final perHour = settings.rateMode == RateMode.perHour;
    final thresholds = settings.activeThresholds;
    final rate = switch (target) {
      Verdict.good =>
        thresholds.goodAtOrAbove + 0.25 + _random.nextDouble() * 0.3,
      Verdict.ok =>
        thresholds.badBelow +
            (thresholds.goodAtOrAbove - thresholds.badBelow) *
                (0.35 + _random.nextDouble() * 0.25),
      Verdict.bad => thresholds.badBelow * (0.65 + _random.nextDouble() * 0.15),
      Verdict.unknown => thresholds.goodAtOrAbove,
    };
    final near = pickupNear ?? true;
    final pickupDistance = near
        ? math.min(settings.pickupNearKm * 0.7, 2.0).toDouble()
        : settings.pickupNearKm + 0.8 + _random.nextDouble() * 1.4;
    final pickupMinutes = 5 + _random.nextInt(8);
    final minimum = settings.minimumPayoutEnabled
        ? settings.minimumPayout
        : 0.0;

    if (belowMinimum) {
      final payout = minimum > 0 ? minimum * 0.75 : 0.5;
      final totalDistance = math
          .max(pickupDistance + 2.0, 4.0 + _random.nextDouble() * 4)
          .toDouble();
      final totalMinutes = math
          .max(30.0, pickupMinutes + 20.0 + _random.nextDouble() * 30)
          .toDouble();
      return _PreviewOfferValues(
        payout: payout,
        pickupDistanceKm: pickupDistance,
        pickupMinutes: pickupMinutes.toDouble(),
        tripDistanceKm: totalDistance - pickupDistance,
        tripMinutes: totalMinutes - pickupMinutes,
      );
    }

    var payout = math
        .max(minimum + 0.75, 8 + _random.nextDouble() * 6)
        .toDouble();
    if (perHour) {
      final totalMinutes = math.max(30.0, payout / rate * 60).toDouble();
      payout = rate * totalMinutes / 60;
      return _PreviewOfferValues(
        payout: payout,
        pickupDistanceKm: pickupDistance,
        pickupMinutes: pickupMinutes.toDouble(),
        tripDistanceKm: math
            .max(1.0, 5.0 + _random.nextDouble() * 5 - pickupDistance)
            .toDouble(),
        tripMinutes: math.max(10.0, totalMinutes - pickupMinutes).toDouble(),
      );
    }

    var totalDistance = math
        .max(pickupDistance + 2.0, payout / rate)
        .toDouble();
    if (payout / totalDistance < rate || payout < minimum) {
      totalDistance = math.max(totalDistance, minimum / rate + 0.5).toDouble();
      payout = rate * totalDistance;
    }
    return _PreviewOfferValues(
      payout: payout,
      pickupDistanceKm: pickupDistance,
      pickupMinutes: pickupMinutes.toDouble(),
      tripDistanceKm: totalDistance - pickupDistance,
      tripMinutes: math.max(10.0, totalDistance * 6 - pickupMinutes).toDouble(),
    );
  }

  void _consumeDeepLink() {
    final tabs = ref.read(tabIndexProvider.notifier);
    final target = tabs.pendingSection;
    if (target == null || target >= _rowKeys.length) return;
    tabs.pendingSection = null;
    setState(() => _open = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Motion.morph, () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _rowKeys[target].currentContext;
          if (ctx == null || !mounted) return;
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.08,
            duration: Motion.morph,
            curve: Motion.curve,
          );
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabIndexProvider, (_, next) {
      if (next == 1) _consumeDeepLink();
    });

    final settings = ref.watch(settingsProvider);
    ref.listen<FoxSettings>(settingsProvider, (_, next) {
      if (!_previewEdited && mounted) {
        _applyPreview(
          _exampleFor(next, Verdict.good),
          distanceUnit: next.distanceUnit,
        );
        setState(() {});
      }
    });
    final controller = ref.read(settingsProvider.notifier);
    final perHour = settings.rateMode == RateMode.perHour;
    final canonicalThresholds = settings.activeThresholds;
    final thresholds = perHour
        ? canonicalThresholds
        : Thresholds(
            goodAtOrAbove: settings.distanceUnit.rateFromPerKm(
              canonicalThresholds.goodAtOrAbove,
            ),
            badBelow: settings.distanceUnit.rateFromPerKm(
              canonicalThresholds.badBelow,
            ),
          );
    final min = perHour ? _minHr : settings.distanceUnit.rateFromPerKm(_minKm);
    final max = perHour ? _maxHr : settings.distanceUnit.rateFromPerKm(_maxKm);
    final unit = perHour ? '/hr' : '/${settings.distanceUnit.shortLabel}';
    final money = settings.currency.prefix;
    final sampleOffer = Offer(
      platform: GigPlatform.uber,
      payout: _samplePayout,
      pickupKm: _pickupDistanceKm,
      dropoffKm: _tripDistanceKm,
      pickupMinutes: _pickupMinutes,
      dropoffMinutes: _tripMinutes,
    );
    final sampleVerdict = _engine.scoreOffer(sampleOffer, settings);
    final scoringPerHour = perHour && sampleOffer.totalMinutes > 0;
    final previewThresholds = scoringPerHour
        ? settings.hourThresholds
        : settings.distanceUnit == DistanceUnit.kilometres
        ? settings.thresholds
        : Thresholds(
            goodAtOrAbove: settings.distanceUnit.rateFromPerKm(
              settings.thresholds.goodAtOrAbove,
            ),
            badBelow: settings.distanceUnit.rateFromPerKm(
              settings.thresholds.badBelow,
            ),
          );
    final previewUnit = scoringPerHour
        ? '/hr'
        : '/${settings.distanceUnit.shortLabel}';
    final activeRate = scoringPerHour
        ? sampleOffer.pricePerHour
        : settings.distanceUnit.rateFromPerKm(sampleOffer.pricePerKm);
    final verdictLabel = sampleVerdict.name.toUpperCase();
    final activeRateText = activeRate.toStringAsFixed(2);
    final badRateText = previewThresholds.badBelow.toStringAsFixed(2);
    final goodRateText = previewThresholds.goodAtOrAbove.toStringAsFixed(2);
    final verdictStyle = VerdictStyle.of(sampleVerdict);
    final minimumFloor =
        settings.minimumPayoutEnabled && _samplePayout < settings.minimumPayout;
    final rateExplanation = minimumFloor
        ? 'Below your $money${settings.minimumPayout.toStringAsFixed(2)} minimum offer'
        : switch (sampleVerdict) {
            Verdict.good => 'Above your $money$goodRateText GOOD threshold',
            Verdict.bad => 'Below your $money$badRateText BAD threshold',
            Verdict.ok => 'Between your GOOD and BAD thresholds',
            Verdict.unknown => 'Rate could not be scored',
          };
    final secondaryRate = scoringPerHour
        ? settings.distanceUnit.rateFromPerKm(sampleOffer.pricePerKm)
        : sampleOffer.pricePerHour;
    final secondaryRateText = secondaryRate.toStringAsFixed(2);
    final secondaryUnit = scoringPerHour
        ? '/${settings.distanceUnit.shortLabel}'
        : '/hr';
    final pickupText =
        'Pickup ${settings.distanceUnit.distanceFromKm(sampleOffer.pickupKm).toStringAsFixed(1)} '
        '${settings.distanceUnit.shortLabel}';
    final secondaryDetail = scoringPerHour
        ? '$pickupText · $money$secondaryRateText$secondaryUnit'
        : '$pickupText · Hourly $money${sampleOffer.pricePerHour.toStringAsFixed(2)}/hr';
    final deliveryPerHour = settings.deliveryRateMode == RateMode.perHour;
    final deliveryCanonical = deliveryPerHour
        ? settings.deliveryHourThresholds
        : settings.deliveryThresholds;
    final deliveryThresholds = deliveryPerHour
        ? deliveryCanonical
        : Thresholds(
            goodAtOrAbove: settings.distanceUnit.rateFromPerKm(
              deliveryCanonical.goodAtOrAbove,
            ),
            badBelow: settings.distanceUnit.rateFromPerKm(
              deliveryCanonical.badBelow,
            ),
          );
    final deliveryMin = deliveryPerHour
        ? _minHr
        : settings.distanceUnit.rateFromPerKm(_minKm);
    final deliveryMax = deliveryPerHour
        ? _maxHr
        : settings.distanceUnit.rateFromPerKm(_maxKm);
    final deliveryUnit = deliveryPerHour
        ? '/hr'
        : '/${settings.distanceUnit.shortLabel}';
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        Gap.sm,
        Gap.md,
        100 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Text('My Rules', style: text.headlineMedium),
        const SizedBox(height: Gap.xs),
        Text(
          'How FoxyCo judges every offer.',
          style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Scoring'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _row(
          0,
          SettingsGroup(
            title: 'Verdict thresholds',
            icon: Icons.tune_rounded,
            summary:
                'OK $money${thresholds.badBelow.toStringAsFixed(2)}–${thresholds.goodAtOrAbove.toStringAsFixed(2)}$unit',
            open: _open == 0,
            accent: _accents[0],
            summaryColor: VerdictColors.ok,
            onTap: () => _toggle(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set the rates for GOOD and BAD. Anything between them is OK.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Center(
                  child: SegmentedButton<RateMode>(
                    segments: [
                      for (final mode in RateMode.values)
                        ButtonSegment(value: mode, label: Text(mode.label)),
                    ],
                    selected: {settings.rateMode},
                    onSelectionChanged: (value) =>
                        controller.setRateMode(value.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: FoxColors.brandFoxSoft,
                      selectedForegroundColor: FoxColors.textPrimary,
                      foregroundColor: FoxColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                if (perHour ||
                    settings.distanceUnit == DistanceUnit.kilometres) ...[
                  PresetChips(
                    current: thresholds,
                    presets: perHour ? _hourPresets : Thresholds.presets,
                    onPick: controller.applyPreset,
                  ),
                  const SizedBox(height: Gap.sm),
                ],
                ThresholdBand(
                  thresholds: thresholds,
                  min: min,
                  max: max,
                  unit: unit,
                ),
                const SizedBox(height: Gap.sm),
                ThresholdSlider(
                  label: 'GOOD at or above',
                  color: VerdictColors.good,
                  value: thresholds.goodAtOrAbove,
                  min: min,
                  max: max,
                  currencyPrefix: money,
                  onChanged: perHour
                      ? controller.setGood
                      : controller.setDisplayedGood,
                ),
                const SizedBox(height: Gap.sm),
                ThresholdSlider(
                  label: 'BAD below',
                  color: VerdictColors.bad,
                  value: thresholds.badBelow,
                  min: min,
                  max: max,
                  currencyPrefix: money,
                  onChanged: perHour
                      ? controller.setBad
                      : controller.setDisplayedBad,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _row(
          1,
          SettingsGroup(
            title: 'Offer guard',
            icon: Icons.shield_outlined,
            summary: [
              if (settings.minimumPayoutEnabled)
                'Min $money${settings.minimumPayout.toStringAsFixed(2)}',
              'Pickup ≤ ${settings.distanceUnit.distanceFromKm(settings.pickupNearKm).toStringAsFixed(1)} ${settings.distanceUnit.shortLabel}',
            ].join(' · '),
            open: _open == 1,
            accent: _accents[1],
            onTap: () => _toggle(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extra protection beyond the normal rate thresholds.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  key: const Key('rules_minimum_payout_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Minimum offer', style: text.titleMedium),
                  value: settings.minimumPayoutEnabled,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setMinimumPayoutEnabled,
                ),
                Text(
                  'Keeps tiny payouts from becoming GOOD on rate alone.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                ThresholdSlider(
                  label: 'BAD if offer is below',
                  color: FoxColors.brandFox,
                  value: settings.minimumPayout.clamp(0, 50),
                  min: 0,
                  max: 50,
                  currencyPrefix: money,
                  enabled: settings.minimumPayoutEnabled,
                  onChanged: controller.setMinimumPayout,
                ),
                const SizedBox(height: Gap.md),
                Divider(color: FoxColors.border),
                const SizedBox(height: Gap.md),
                Text('Pickup distance', style: text.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  'Green = within the limit; red = over it. Pickup is '
                  'informational and does not change GOOD/OK/BAD.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                ThresholdSlider(
                  label: 'Near pickup at or under',
                  color: VerdictColors.good,
                  value: settings.distanceUnit.distanceFromKm(
                    settings.pickupNearKm,
                  ),
                  min: settings.distanceUnit.distanceFromKm(0.5),
                  max: settings.distanceUnit.distanceFromKm(10),
                  unit: settings.distanceUnit.shortLabel,
                  visualValue: (value) {
                    final min = settings.distanceUnit.distanceFromKm(0.5);
                    final max = settings.distanceUnit.distanceFromKm(10);
                    final fraction = ((value - min) / (max - min)).clamp(
                      0.0,
                      1.0,
                    );
                    return min + (max - min) * math.sqrt(fraction);
                  },
                  actualValue: (visual) {
                    final min = settings.distanceUnit.distanceFromKm(0.5);
                    final max = settings.distanceUnit.distanceFromKm(10);
                    final fraction = ((visual - min) / (max - min)).clamp(
                      0.0,
                      1.0,
                    );
                    return min + (max - min) * fraction * fraction;
                  },
                  onChanged: controller.setDisplayedPickupNear,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _row(
          2,
          SettingsGroup(
            title: 'Live preview',
            icon: Icons.visibility_outlined,
            summary: 'See how your rules score an offer',
            open: _open == 2,
            accent: _accents[2],
            onTap: () => _toggle(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _previewField(
                  'Offer price',
                  _payoutController,
                  (v) => _changePreview(
                    () => _samplePayout = v.clamp(0, 500).toDouble(),
                  ),
                  prefix: money,
                ),
                const SizedBox(height: Gap.sm),
                Text('Pickup', style: text.titleSmall),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    Expanded(
                      child: _previewField(
                        'Distance',
                        _pickupDistanceController,
                        (v) => _changePreview(
                          () => _pickupDistanceKm = settings.distanceUnit
                              .distanceToKm(v.clamp(0, 100).toDouble()),
                        ),
                        suffix: settings.distanceUnit.shortLabel,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Hours',
                        _pickupHoursController,
                        (v) => _changePreview(
                          () => _pickupMinutes =
                              v.clamp(0, 24).toDouble() * 60 +
                              (double.tryParse(_pickupMinutesController.text) ??
                                      0)
                                  .clamp(0, 59)
                                  .toDouble(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Minutes',
                        _pickupMinutesController,
                        (v) => _changePreview(
                          () => _pickupMinutes =
                              (_pickupMinutes ~/ 60) * 60 +
                              v.clamp(0, 59).toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text('Trip', style: text.titleSmall),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    Expanded(
                      child: _previewField(
                        'Distance',
                        _tripDistanceController,
                        (v) => _changePreview(
                          () => _tripDistanceKm = settings.distanceUnit
                              .distanceToKm(v.clamp(0, 500).toDouble()),
                        ),
                        suffix: settings.distanceUnit.shortLabel,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Hours',
                        _tripHoursController,
                        (v) => _changePreview(
                          () => _tripMinutes =
                              v.clamp(0, 48).toDouble() * 60 +
                              (double.tryParse(_tripMinutesController.text) ??
                                      0)
                                  .clamp(0, 59)
                                  .toDouble(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Minutes',
                        _tripMinutesController,
                        (v) => _changePreview(
                          () => _tripMinutes =
                              (_tripMinutes ~/ 60) * 60 +
                              v.clamp(0, 59).toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                OutlinedButton.icon(
                  key: const Key('rules_try_example'),
                  onPressed: () => _tryExample(settings),
                  icon: const Icon(Icons.shuffle_rounded, size: 17),
                  label: const Text('Try another example'),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  verdictLabel,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: verdictStyle.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$money$activeRateText$previewUnit',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    color: verdictStyle.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      rateExplanation,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: FoxColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: VerdictPill(
                      payload: OverlayPayload(
                        verdict: sampleVerdict,
                        totalKm: sampleOffer.totalKm,
                        payout: sampleOffer.payout,
                        totalMinutes: sampleOffer.totalMinutes,
                        rateMode: settings.rateMode,
                        size: PillSize.medium,
                        distanceUnit: settings.distanceUnit,
                        currency: settings.currency,
                        pickupKm: sampleOffer.pickupKm,
                        pickupNearKm: settings.pickupNearKm,
                        hourGoodAt: settings.hourThresholds.goodAtOrAbove,
                        hourBadBelow: settings.hourThresholds.badBelow,
                      ),
                      targetColor: verdictStyle.color,
                      animate: false,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  secondaryDetail,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: FoxColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Platforms'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _row(
          3,
          SettingsGroup(
            title: 'Watched apps',
            icon: Icons.apps_rounded,
            summary: settings.watchedApps.map((app) => app.label).join(' · '),
            open: _open == 3,
            accent: _accents[3],
            onTap: () => _toggle(3),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final app in ParserRegistry.supportedPlatforms) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: PlatformBadge(platform: app, size: 22),
                      title: Text(app.label, style: text.titleMedium),
                      subtitle: app.isBeta
                          ? const Text('Beta · best effort')
                          : (!settings.watches(app) &&
                                settings.watchedApps.length >=
                                    FoxSettings.maxWatchedApps)
                          ? const Text('Turn off another app first')
                          : null,
                      value: settings.watches(app),
                      activeTrackColor: FoxColors.brandFox,
                      onChanged:
                          settings.watches(app) ||
                              settings.watchedApps.length <
                                  FoxSettings.maxWatchedApps
                          ? (_) => controller.toggleApp(app)
                          : null,
                    ),
                    if (app != ParserRegistry.supportedPlatforms.last)
                      Divider(color: FoxColors.border, height: 1),
                  ],
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Choose up to ${FoxSettings.maxWatchedApps} apps. Your selection is saved for the next session.',
                    style: text.bodySmall?.copyWith(
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (settings.watchesDelivery) ...[
          const SizedBox(height: Gap.sm),
          _row(
            5,
            SettingsGroup(
              title: 'Delivery rules',
              icon: Icons.local_shipping_outlined,
              summary:
                  'Beta · GOOD $money${deliveryThresholds.goodAtOrAbove.toStringAsFixed(2)}$deliveryUnit',
              open: _open == 5,
              accent: _accents[5],
              onTap: () => _toggle(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Used only for DoorDash, Instacart and Skip. Ride rules above '
                    'continue to control Uber, Lyft and Hopp.',
                    style: text.bodyMedium?.copyWith(
                      color: FoxColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Center(
                    child: SegmentedButton<RateMode>(
                      segments: [
                        for (final mode in RateMode.values)
                          ButtonSegment(value: mode, label: Text(mode.label)),
                      ],
                      selected: {settings.deliveryRateMode},
                      onSelectionChanged: (value) =>
                          controller.setDeliveryRateMode(value.first),
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  ThresholdBand(
                    thresholds: deliveryThresholds,
                    min: deliveryMin,
                    max: deliveryMax,
                    unit: deliveryUnit,
                  ),
                  const SizedBox(height: Gap.sm),
                  ThresholdSlider(
                    label: 'GOOD at or above',
                    color: VerdictColors.good,
                    value: deliveryThresholds.goodAtOrAbove,
                    min: deliveryMin,
                    max: deliveryMax,
                    currencyPrefix: money,
                    onChanged: controller.setDeliveryGood,
                  ),
                  const SizedBox(height: Gap.sm),
                  ThresholdSlider(
                    label: 'BAD below',
                    color: VerdictColors.bad,
                    value: deliveryThresholds.badBelow,
                    min: deliveryMin,
                    max: deliveryMax,
                    currencyPrefix: money,
                    onChanged: controller.setDeliveryBad,
                  ),
                  Divider(color: FoxColors.border, height: Gap.xl),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Minimum delivery offer',
                      style: text.titleMedium,
                    ),
                    value: settings.deliveryMinimumPayoutEnabled,
                    activeTrackColor: FoxColors.brandFox,
                    onChanged: controller.setDeliveryMinimumPayoutEnabled,
                  ),
                  ThresholdSlider(
                    label: 'BAD if offer is below',
                    color: FoxColors.brandFox,
                    value: settings.deliveryMinimumPayout.clamp(0, 50),
                    min: 0,
                    max: 50,
                    currencyPrefix: money,
                    enabled: settings.deliveryMinimumPayoutEnabled,
                    onChanged: controller.setDeliveryMinimumPayout,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        const SectionLabel('Alerts'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _row(
          4,
          SettingsGroup(
            title: 'Voice announcements',
            icon: Icons.volume_up_rounded,
            summary: switch ((
              settings.voiceVerdictEnabled,
              settings.announceGoodOffers,
              settings.announceOkOffers,
            )) {
              (false, _, _) => 'Off',
              (true, true, true) => 'GOOD + OK',
              (true, true, false) => 'GOOD only',
              (true, false, true) => 'OK only',
              _ => 'Off',
            },
            open: _open == 4,
            accent: _accents[4],
            onTap: () => _toggle(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const Key('rules_voice_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Voice announcements', style: text.titleMedium),
                  subtitle: const Text(
                    'Hear selected verdicts without looking at the screen.',
                  ),
                  value: settings.voiceVerdictEnabled,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setVoiceVerdictEnabled,
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  key: const Key('rules_voice_good_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('GOOD offers', style: text.titleMedium),
                  subtitle: const Text('Announce offers rated GOOD.'),
                  value: settings.announceGoodOffers,
                  activeTrackColor: VerdictColors.good,
                  onChanged: settings.voiceVerdictEnabled
                      ? controller.setAnnounceGoodOffers
                      : null,
                ),
                SwitchListTile(
                  key: const Key('rules_voice_ok_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('OK offers', style: text.titleMedium),
                  subtitle: const Text('Also announce offers rated OK.'),
                  value: settings.announceOkOffers,
                  activeTrackColor: VerdictColors.ok,
                  onChanged: settings.voiceVerdictEnabled
                      ? controller.setAnnounceOkOffers
                      : null,
                ),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text('Minimum interval', style: text.titleMedium),
                    ),
                    Text(
                      '${settings.voiceCooldownSeconds} sec',
                      style: text.titleMedium?.copyWith(
                        color: FoxColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Opacity(
                  opacity: settings.voiceVerdictEnabled ? 1 : 0.45,
                  child: RoadSlider(
                    key: const Key('rules_voice_cooldown'),
                    value: settings.voiceCooldownSeconds.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    color: FoxColors.brandFox,
                    enabled: settings.voiceVerdictEnabled,
                    onChanged: (value) => controller.setVoiceCooldownSeconds(
                      (value / 5).round() * 5,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('rules_voice_preview'),
                        onPressed: settings.voiceVerdictEnabled
                            ? () => unawaited(
                                ref
                                    .read(verdictVoiceProvider)
                                    .preview(Verdict.good),
                              )
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VerdictColors.good,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: const Text('Preview GOOD'),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('rules_voice_ok_preview'),
                        onPressed: settings.voiceVerdictEnabled
                            ? () => unawaited(
                                ref
                                    .read(verdictVoiceProvider)
                                    .preview(Verdict.ok),
                              )
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VerdictColors.ok,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: const Text('Preview OK'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(int index, Widget child) =>
      KeyedSubtree(key: _rowKeys[index], child: child);
}
