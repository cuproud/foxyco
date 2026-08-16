import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/decision_engine.dart';
import '../../domain/distance_unit.dart';
import '../../domain/offer.dart';
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../services/verdict_voice.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_controls.dart';
import '../shell/root_shell.dart';
import '../theme/platform_badge.dart';
import '../theme/section_label.dart';
import '../theme/tokens.dart';

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

  static List<Color> get _accents => [
    VerdictColors.good,
    const Color(0xFF5EC2CD),
    const Color(0xFF4FA3E8),
    const Color(0xFFB48AE8),
    const Color(0xFFF0A24B),
  ];

  double _samplePpk = 1.25;
  double _samplePph = 25.0;
  double _samplePayout = 10;
  int _open = 0;
  final _rowKeys = List.generate(5, (_) => GlobalKey());

  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);

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
    final sample = perHour ? _samplePph : _samplePpk;
    final sampleOffer = Offer(
      platform: GigPlatform.uber,
      payout: _samplePayout,
      pickupKm: perHour ? 1 : _samplePayout / sample,
      dropoffKm: 0,
      pickupMinutes: perHour ? _samplePayout / sample * 60 : 0,
    );
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
                'GOOD ≥ $money${thresholds.goodAtOrAbove.toStringAsFixed(2)}$unit',
            open: _open == 0,
            accent: _accents[0],
            onTap: () => _toggle(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  perHour
                      ? 'Offers are scored by dollars per hour. Set where GOOD and BAD begin.'
                      : 'Offers are scored by dollars per ${settings.distanceUnit.label.toLowerCase()}. Set where GOOD and BAD begin.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.md),
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
                const SizedBox(height: Gap.md),
                if (!perHour &&
                    settings.distanceUnit == DistanceUnit.kilometres) ...[
                  PresetChips(
                    current: thresholds,
                    onPick: controller.applyPreset,
                  ),
                  const SizedBox(height: Gap.md),
                ],
                ThresholdBand(
                  thresholds: thresholds,
                  min: min,
                  max: max,
                  unit: unit,
                ),
                const SizedBox(height: Gap.md),
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
                const SizedBox(height: Gap.md),
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
                const SizedBox(height: Gap.md),
                Divider(color: FoxColors.border),
                SwitchListTile(
                  key: const Key('rules_minimum_payout_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Minimum offer amount', style: text.titleMedium),
                  subtitle: Text(
                    'Judge offers below a custom payout before the rate rules.',
                    style: text.bodyMedium?.copyWith(
                      color: FoxColors.textSecondary,
                    ),
                  ),
                  value: settings.minimumPayoutEnabled,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setMinimumPayoutEnabled,
                ),
                if (settings.minimumPayoutEnabled) ...[
                  const SizedBox(height: Gap.sm),
                  ThresholdSlider(
                    label: 'Offers below',
                    color: FoxColors.brandFox,
                    value: settings.minimumPayout.clamp(0, 50),
                    min: 0,
                    max: 50,
                    currencyPrefix: money,
                    onChanged: controller.setMinimumPayout,
                  ),
                  const SizedBox(height: Gap.sm),
                  Semantics(
                    label: 'Verdict for offers below minimum amount',
                    child: SegmentedButton<Verdict>(
                      key: const Key('rules_minimum_payout_verdict'),
                      segments: const [
                        ButtonSegment(value: Verdict.bad, label: Text('BAD')),
                        ButtonSegment(value: Verdict.ok, label: Text('OK')),
                        ButtonSegment(value: Verdict.good, label: Text('GOOD')),
                      ],
                      selected: {settings.minimumPayoutVerdict},
                      onSelectionChanged: (selection) =>
                          controller.setMinimumPayoutVerdict(selection.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: FoxColors.brandFoxSoft,
                        selectedForegroundColor: FoxColors.textPrimary,
                        foregroundColor: FoxColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _row(
          1,
          SettingsGroup(
            title: 'Live preview',
            icon: Icons.visibility_outlined,
            summary: 'Try a sample rate',
            open: _open == 1,
            accent: _accents[1],
            onTap: () => _toggle(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ThresholdSlider(
                  label: 'Sample payout',
                  color: FoxColors.brandFox,
                  value: _samplePayout,
                  min: 1,
                  max: 50,
                  currencyPrefix: money,
                  onChanged: (value) => setState(() => _samplePayout = value),
                ),
                const SizedBox(height: Gap.sm),
                PreviewCard(
                  sample: sample,
                  unit: unit,
                  verdict: _engine.scoreOffer(sampleOffer, settings),
                  min: min,
                  max: max,
                  currencyPrefix: money,
                  onChanged: (value) => setState(() {
                    if (perHour) {
                      _samplePph = value;
                    } else {
                      _samplePpk = value;
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _row(
          2,
          SettingsGroup(
            title: 'Pickup guard',
            icon: Icons.near_me_outlined,
            summary:
                'Near ≤ ${settings.distanceUnit.distanceFromKm(settings.pickupNearKm).toStringAsFixed(1)} ${settings.distanceUnit.shortLabel}',
            open: _open == 2,
            accent: _accents[2],
            onTap: () => _toggle(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThresholdSlider(
                  label: 'Near pickup at or under',
                  color: FoxColors.brandFox,
                  value: settings.distanceUnit.distanceFromKm(
                    settings.pickupNearKm,
                  ),
                  min: settings.distanceUnit.distanceFromKm(0.5),
                  max: settings.distanceUnit.distanceFromKm(10),
                  unit: settings.distanceUnit.shortLabel,
                  onChanged: controller.setDisplayedPickupNear,
                ),
                Text(
                  'Pickups under this distance show green on the pill; longer dead runs show red.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
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
                    'GOOD when the active rate is at least $money${thresholds.goodAtOrAbove.toStringAsFixed(2)}$unit.',
                  ),
                  value: settings.announceGoodOffers,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setAnnounceGoodOffers,
                ),
                const SizedBox(height: Gap.sm),
                SwitchListTile(
                  key: const Key('rules_voice_ok_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Announce OK offers', style: text.titleMedium),
                  subtitle: Text(
                    'OK from $money${thresholds.badBelow.toStringAsFixed(2)} up to the GOOD threshold.',
                  ),
                  value: settings.announceOkOffers,
                  activeTrackColor: FoxColors.brandFox,
                  onChanged: controller.setAnnounceOkOffers,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Minimum time between announcements: ${settings.voiceCooldownSeconds} seconds',
                  style: text.titleMedium,
                ),
                Slider(
                  key: const Key('rules_voice_cooldown'),
                  value: settings.voiceCooldownSeconds.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  activeColor: FoxColors.brandFox,
                  label: '${settings.voiceCooldownSeconds} seconds',
                  onChanged: (value) => controller.setVoiceCooldownSeconds(
                    (value / 5).round() * 5,
                  ),
                ),
                if (settings.minimumPayoutEnabled) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Payout floor runs first: below $money${settings.minimumPayout.toStringAsFixed(2)} is ${settings.minimumPayoutVerdict.name.toUpperCase()}.',
                    style: text.bodyMedium?.copyWith(
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
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
