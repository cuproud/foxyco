import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/distance_unit.dart';
import '../../domain/offer.dart';
import '../../domain/overlay_payload.dart';
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
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
  ];

  double _samplePayout = 10;
  double _sampleDistanceKm = 3.5;
  double _sampleMinutes = 44;
  int _open = 0;
  final _rowKeys = List.generate(5, (_) => GlobalKey());
  late final TextEditingController _payoutController;
  late final TextEditingController _distanceController;
  late final TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _payoutController = TextEditingController(
      text: _samplePayout.toStringAsFixed(2),
    );
    _distanceController = TextEditingController(
      text: _sampleDistanceKm.toStringAsFixed(1),
    );
    _minutesController = TextEditingController(
      text: _sampleMinutes.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _payoutController.dispose();
    _distanceController.dispose();
    _minutesController.dispose();
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
      pickupKm: _sampleDistanceKm,
      dropoffKm: 0,
      pickupMinutes: _sampleMinutes,
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
            Verdict.ok =>
              'Between your $money$badRateText and $money$goodRateText OK range',
            Verdict.unknown => 'Rate could not be scored',
          };
    final pickupNear = sampleOffer.pickupKm <= settings.pickupNearKm;
    final pickupLimit = settings.distanceUnit
        .distanceFromKm(settings.pickupNearKm)
        .toStringAsFixed(1);
    final secondaryRate = scoringPerHour
        ? settings.distanceUnit.rateFromPerKm(sampleOffer.pricePerKm)
        : sampleOffer.pricePerHour;
    final secondaryRateText = secondaryRate.toStringAsFixed(2);
    final secondaryUnit = scoringPerHour
        ? '/${settings.distanceUnit.shortLabel}'
        : '/hr';
    final secondaryLabel = scoringPerHour
        ? '\$/${settings.distanceUnit.shortLabel}'
        : '\$/hr';
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
                  perHour
                      ? 'Set the hourly rates you consider GOOD or BAD. Anything in between is OK.'
                      : 'Set the rates you consider GOOD or BAD. Anything in between is OK.',
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
                  "Extra protection from offers that aren't worth it, even when the rate looks good.",
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
                  'Tiny payouts stay BAD even when the rate looks good.',
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
                  'Highlight pickup distance in the offer pill.',
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
                Row(
                  children: [
                    Expanded(
                      child: _previewField(
                        'Payout',
                        _payoutController,
                        (v) => setState(
                          () => _samplePayout = v.clamp(0, 500).toDouble(),
                        ),
                        prefix: money,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Distance',
                        _distanceController,
                        (v) => setState(
                          () =>
                              _sampleDistanceKm = v.clamp(0.1, 500).toDouble(),
                        ),
                        suffix: 'km',
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: _previewField(
                        'Time',
                        _minutesController,
                        (v) => setState(
                          () => _sampleMinutes = v.clamp(1, 1440).toDouble(),
                        ),
                        suffix: 'min',
                      ),
                    ),
                  ],
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
                Text(
                  rateExplanation,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: VerdictPill(
                      payload: OverlayPayload(
                        verdict: sampleVerdict,
                        totalKm: sampleOffer.totalKm,
                        payout: sampleOffer.payout,
                        totalMinutes: sampleOffer.totalMinutes,
                        size: PillSize.medium,
                        distanceUnit: settings.distanceUnit,
                        currency: settings.currency,
                        pickupKm: sampleOffer.pickupKm,
                        pickupNearKm: settings.pickupNearKm,
                        hourGoodAt: settings.hourThresholds.goodAtOrAbove,
                        hourBadBelow: settings.hourThresholds.badBelow,
                      ),
                      animate: false,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Gap.sm,
                  children: [
                    Text(
                      '$secondaryLabel $money$secondaryRateText$secondaryUnit',
                      style: text.bodySmall?.copyWith(
                        color: FoxColors.textSecondary,
                      ),
                    ),
                    Text(
                      pickupNear
                          ? 'At or under $pickupLimit ${settings.distanceUnit.shortLabel}'
                          : 'Over $pickupLimit ${settings.distanceUnit.shortLabel}',
                      style: text.bodySmall?.copyWith(
                        color: pickupNear
                            ? VerdictColors.good
                            : VerdictColors.bad,
                      ),
                    ),
                  ],
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
                  for (final app in GigPlatform.values) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: PlatformBadge(platform: app, size: 22),
                      title: Text(app.label, style: text.titleMedium),
                      value: settings.watches(app),
                      activeTrackColor: FoxColors.brandFox,
                      onChanged: (_) => controller.toggleApp(app),
                    ),
                    if (app != GigPlatform.values.last)
                      Divider(color: FoxColors.border, height: 1),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Alerts'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _row(
          4,
          SettingsGroup(
            title: 'Voice verdict',
            icon: Icons.volume_up_rounded,
            summary: switch ((
              settings.announceGoodOffers,
              settings.announceOkOffers,
            )) {
              (true, true) => 'GOOD and OK offers',
              (true, false) => 'GOOD offers',
              (false, true) => 'OK offers',
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
                  title: Text('Announce GOOD offers', style: text.titleMedium),
                  subtitle: Text(
                    'Only when the offer passes both rate rules and your payout cutoff.',
                  ),
                  value: settings.announceGoodOffers,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setAnnounceGoodOffers,
                ),
                ThresholdSlider(
                  key: const Key('rules_voice_good_payout'),
                  label: 'GOOD voice payout at least',
                  color: VerdictColors.good,
                  value: settings.goodVoiceMinimumPayout,
                  min: 0,
                  max: 500,
                  currencyPrefix: money,
                  editable: true,
                  onEdit: controller.setGoodVoiceMinimumPayout,
                  onChanged: controller.setGoodVoiceMinimumPayout,
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  key: const Key('rules_voice_ok_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Announce OK offers', style: text.titleMedium),
                  subtitle: Text(
                    'Only OK verdicts at or above your payout cutoff.',
                  ),
                  value: settings.announceOkOffers,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setAnnounceOkOffers,
                ),
                ThresholdSlider(
                  key: const Key('rules_voice_ok_payout'),
                  label: 'OK voice payout at least',
                  color: VerdictColors.ok,
                  value: settings.okVoiceMinimumPayout,
                  min: 0,
                  max: 500,
                  currencyPrefix: money,
                  editable: true,
                  onEdit: controller.setOkVoiceMinimumPayout,
                  onChanged: controller.setOkVoiceMinimumPayout,
                ),
                Text(
                  'GOOD checks both \$/km and \$/hr rules before this payout cutoff. Set either cutoff to ${money}0 to allow every matching verdict.',
                  style: text.bodySmall?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Minimum time between announcements: ${settings.voiceCooldownSeconds} seconds',
                  style: text.titleMedium,
                ),
                RoadSlider(
                  key: const Key('rules_voice_cooldown'),
                  value: settings.voiceCooldownSeconds.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  color: FoxColors.brandFox,
                  onChanged: (value) => controller.setVoiceCooldownSeconds(
                    (value / 5).round() * 5,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('rules_voice_preview'),
                      onPressed: () => unawaited(
                        ref.read(verdictVoiceProvider).preview(Verdict.good),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Preview GOOD'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('rules_voice_ok_preview'),
                      onPressed: () => unawaited(
                        ref.read(verdictVoiceProvider).preview(Verdict.ok),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Preview OK'),
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
