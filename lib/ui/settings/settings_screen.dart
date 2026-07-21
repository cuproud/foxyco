import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/decision_engine.dart';
import '../../domain/fox_settings.dart';
import '../../domain/garage.dart';
import '../../domain/money_font.dart';
import '../../domain/overlay_payload.dart' show OverlayPayload, PillSize;
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../../services/parse_health.dart';
import '../overlay/verdict_pill.dart';
import '../theme/platform_badge.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_badge.dart';
import '../theme/verdict_style.dart';
import 'garage_controller.dart';
import 'reminder_controller.dart';
import 'reminder_section.dart';
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

  /// Single-open accordion index (-1 = all collapsed); Driver open by default.
  int _open = 0;
  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);

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
    final garage = ref.watch(garageProvider);
    final reminders = ref.watch(reminderProvider);
    final driverName = ref.watch(driverNameProvider);

    return ListView(
      // 100 clears the floating nav; add the gesture-bar inset like Home does
      // (fixed 100 clipped the last card on gesture-nav phones).
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        Gap.sm,
        Gap.md,
        100 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Row(
          children: [
            Text('Settings', style: text.headlineMedium),
            const Spacer(),
            TextButton(
              onPressed: () => _confirmReset(context, controller),
              style: TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              child: const Text(
                'Reset',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _staggered(
          0,
          _SettingsGroup(
            title: 'Driver',
            icon: Icons.person_outline_rounded,
            summary: driverName.isNotEmpty ? driverName : 'Set your name',
            open: _open == 0,
            onTap: () => _toggle(0),
            child: const _DriverNameCard(),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          1,
          _SettingsGroup(
            title: 'Garage',
            icon: Icons.garage_outlined,
            summary:
                '${garage.vehicles.length} vehicle'
                '${garage.vehicles.length == 1 ? '' : 's'} · '
                '${reminders.length} reminder'
                '${reminders.length == 1 ? '' : 's'}',
            open: _open == 1,
            onTap: () => _toggle(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _GarageList(),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 14,
                      color: FoxColors.textDisabled,
                    ),
                    const SizedBox(width: 6),
                    Text('CAR REMINDERS', style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                const ReminderSection(),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          2,
          _SettingsGroup(
            title: 'Verdict thresholds',
            icon: Icons.tune_rounded,
            summary: 'GOOD ≥ \$${t.goodAtOrAbove.toStringAsFixed(2)}$unit',
            open: _open == 2,
            onTap: () => _toggle(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  perHour
                      ? 'Offers are scored by dollars per hour. Set where '
                            'GOOD and BAD begin.'
                      : 'Offers are scored by dollars per kilometre. Set '
                            'where GOOD and BAD begin.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.md),
                // Rate mode — each mode keeps its own cut points. Offers
                // with no parsed time fall back to $/km (engine fail-safe).
                Center(
                  child: SegmentedButton<RateMode>(
                    segments: [
                      for (final m in RateMode.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {settings.rateMode},
                    onSelectionChanged: (s) => controller.setRateMode(s.first),
                    style: SegmentedButton.styleFrom(
                      // Deep-orange-on-orange was a leftover from the
                      // cream theme — unreadable on dark. Cream on the
                      // orange tint reads.
                      selectedBackgroundColor: FoxColors.brandFoxSoft,
                      selectedForegroundColor: FoxColors.cream,
                      foregroundColor: FoxColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                // One-tap starting points (same trio as onboarding).
                // Only shown in $/km mode — the presets are $/km numbers.
                if (!perHour) ...[
                  _PresetChips(current: t, onPick: controller.applyPreset),
                  const SizedBox(height: Gap.md),
                ],
                _ThresholdBand(thresholds: t, min: min, max: max, unit: unit),
                const SizedBox(height: Gap.md),
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
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          3,
          _SettingsGroup(
            title: 'Live preview',
            icon: Icons.visibility_outlined,
            summary: 'Try a sample rate',
            open: _open == 3,
            onTap: () => _toggle(3),
            child: _PreviewCard(
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
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          4,
          _SettingsGroup(
            title: 'Pickup guard',
            icon: Icons.near_me_outlined,
            summary: 'Near ≤ ${settings.pickupNearKm.toStringAsFixed(1)} km',
            open: _open == 4,
            onTap: () => _toggle(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThresholdSlider(
                  label: 'Near pickup at or under',
                  color: FoxColors.brandFox,
                  value: settings.pickupNearKm,
                  min: 0.5,
                  max: 10.0,
                  unit: 'km',
                  onChanged: controller.setPickupNearKm,
                ),
                Text(
                  'Pickups under this distance show green on the pill; '
                  'longer dead runs show red.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          5,
          _SettingsGroup(
            title: 'Watched apps',
            icon: Icons.apps_rounded,
            summary: settings.watchedApps.map((a) => a.label).join(' · '),
            open: _open == 5,
            onTap: () => _toggle(5),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final app in GigPlatform.values) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      // Badge matches History's chips — same identity mark
                      // everywhere app name appears.
                      secondary: PlatformBadge(platform: app, size: 22),
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
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          6,
          _SettingsGroup(
            title: 'Outcome tracking',
            icon: Icons.fact_check_outlined,
            summary: settings.trackOutcomes ? 'On' : 'Off',
            open: _open == 6,
            onTap: () => _toggle(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Guess taken / passed',
                      style: text.titleMedium,
                    ),
                    value: settings.trackOutcomes,
                    activeTrackColor: FoxColors.brandFox,
                    onChanged: controller.setTrackOutcomes,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'After an offer card disappears, FoxyCo guesses what '
                  'happened from the screen that replaced it: back to the '
                  'map means you passed, a pickup screen means you took '
                  'it. It\'s an estimate — shown as ✓/✕ in History and '
                  'never 100% certain. FoxyCo only reads the screen; it '
                  'never taps or accepts anything for you. Turn this off '
                  'and offers are logged without a taken/passed mark.',
                  style: text.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.45,
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          7,
          _SettingsGroup(
            title: 'Pill size',
            icon: Icons.circle_outlined,
            summary: switch (settings.pillSize) {
              PillSize.small => 'Small',
              PillSize.medium => 'Medium',
              PillSize.large => 'Large',
            },
            open: _open == 7,
            onTap: () => _toggle(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChoiceRow<PillSize>(
                  values: PillSize.values,
                  selected: settings.pillSize,
                  labelOf: (s) => switch (s) {
                    PillSize.small => 'Small',
                    PillSize.medium => 'Medium',
                    PillSize.large => 'Large',
                  },
                  onChanged: controller.setPillSize,
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                // Live preview — sample payload at the selected size, so the
                // change is visible instantly without waiting for a real offer.
                // FittedBox: a Large pill wider than a narrow phone minus
                // page padding overflowed the stripes (device 2026-07-19);
                // scale-down keeps the whole thing instead.
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: VerdictPill(
                      payload: const OverlayPayload(
                        verdict: Verdict.good,
                        totalKm: 8.4,
                        payout: 12,
                        totalMinutes: 24,
                        pickupKm: 2.1,
                        pickupNearKm: 3,
                      ),
                      size: settings.pillSize,
                      // Static ring in preview: the orbit loop would keep the
                      // settings list repainting forever for decorative detail.
                      animate: false,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                // Quick "how to read it" legend for first-time users — mirrors
                // the sample pill above (M6 follow-up, device 2026-07-19).
                const _PillLegend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          8,
          _SettingsGroup(
            title: 'Appearance',
            icon: Icons.text_fields_rounded,
            summary: settings.moneyFont.label,
            open: _open == 8,
            onTap: () => _toggle(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Typeface for the big money numbers — pill, home and '
                  'history.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.md),
                for (final f in MoneyFont.values) ...[
                  _FontChoiceCard(
                    font: f,
                    selected: settings.moneyFont == f,
                    onTap: () => controller.setMoneyFont(f),
                  ),
                  if (f != MoneyFont.values.last)
                    const SizedBox(height: Gap.sm),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          9,
          _SettingsGroup(
            title: 'Parser health',
            icon: Icons.monitor_heart_outlined,
            summary: 'This session',
            open: _open == 9,
            onTap: () => _toggle(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    for (final app in GigPlatform.values) ...[
                      _HealthRow(
                        app: app,
                        watched: settings.watches(app),
                        health:
                            ref.watch(parseHealthProvider)[app] ??
                            const PlatformHealth(),
                      ),
                      if (app != GigPlatform.values.last)
                        const Divider(color: FoxColors.border, height: Gap.lg),
                    ],
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'This session. "Needs update" means offer cards are arriving '
                  'but FoxyCo can\'t read them — the app\'s layout likely '
                  'changed.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          10,
          _SettingsGroup(
            title: 'History',
            icon: Icons.history_rounded,
            summary: settings.retentionDays == FoxSettings.keepForever
                ? 'Keep forever'
                : 'Keep ${settings.retentionDays} days',
            open: _open == 10,
            onTap: () => _toggle(10),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _exportCsv(context),
                      style: TextButton.styleFrom(
                        foregroundColor: FoxColors.brandFox,
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text(
                        'Export CSV',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    TextButton(
                      onPressed: () => _confirmClear(context),
                      style: TextButton.styleFrom(
                        foregroundColor: VerdictColors.bad,
                      ),
                      child: const Text(
                        'Clear offer history',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  /// Section-entry stagger (spec M6 §6): each section fades + slides up with a
  /// small per-index delay. Reduced-motion or below-the-fold sections (i > 7)
  /// render instantly — no loops, no jank.
  Widget _staggered(int i, Widget child) {
    if (MediaQuery.of(context).disableAnimations || i > 7) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * i,
      curve: Motion.curve,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
      child: child,
    );
  }

  /// Share the whole offer log as CSV — the log is capped at 2000 rows, so
  /// building the string in memory is fine.
  Future<void> _exportCsv(BuildContext context) async {
    final offers = ref.read(offerLogProvider);
    if (offers.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No offers to export yet'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final buf = StringBuffer(
      'seen_at,app,verdict,fare,total_km,pickup_km,minutes,per_km,per_hour,outcome\n',
    );
    for (final o in offers) {
      buf.writeln(
        [
          o.seenAt.toIso8601String(),
          o.platform.label,
          o.verdict.name,
          o.payout.toStringAsFixed(2),
          o.totalKm.toStringAsFixed(1),
          o.pickupKm.toStringAsFixed(1),
          o.totalMinutes.toStringAsFixed(0),
          o.pricePerKm.toStringAsFixed(2),
          o.pricePerHour.toStringAsFixed(2),
          o.outcome.name,
        ].join(','),
      );
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(buf.toString())),
            mimeType: 'text/csv',
            name: 'foxyco_offers.csv',
          ),
        ],
        fileNameOverrides: ['foxyco_offers.csv'],
      ),
    );
  }

  /// Reset wipes every tuned knob (thresholds, apps, pill, retention) — as
  /// destructive as clear-history, so it gets the same confirm gate.
  Future<void> _confirmReset(
    BuildContext context,
    SettingsController controller,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all settings?'),
        content: const Text(
          'Thresholds, watched apps, pill size and retention go back to '
          'defaults. Your offer history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes == true) controller.reset();
  }

  Future<void> _confirmClear(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear offer history?'),
        content: const Text(
          'Every logged offer is deleted. This cannot be undone.',
        ),
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

/// One-tap threshold presets (shared trio with onboarding). Highlights the
/// preset matching the current cut points; custom slider positions match none.
class _PresetChips extends StatelessWidget {
  const _PresetChips({required this.current, required this.onPick});

  final Thresholds current;
  final ValueChanged<Thresholds> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, t) in Thresholds.presets) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(t);
              },
              child: AnimatedContainer(
                duration: Motion.base,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: current == t
                      ? FoxColors.brandFoxSoft
                      : FoxColors.bgSurface2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: current == t
                        ? FoxColors.brandFox.withValues(alpha: 0.6)
                        : FoxColors.borderSoft,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: current == t
                          ? FoxColors.cream
                          : FoxColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if ((label, t) != Thresholds.presets.last)
            const SizedBox(width: Gap.sm),
        ],
      ],
    );
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
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              child: AnimatedContainer(
                duration: Motion.base,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: v == selected
                      ? FoxColors.bgSurface2
                      : FoxColors.bgSurface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: v == selected
                        ? FoxColors.border
                        : FoxColors.borderSoft,
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

/// One platform's session parse health: OK / quiet / needs-update. Row stays
/// dimmed for apps the driver isn't watching (their health is moot).
class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.app,
    required this.watched,
    required this.health,
  });

  final GigPlatform app;
  final bool watched;
  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, color, bg) = !watched
        ? ('Off', FoxColors.textDisabled, FoxColors.bgBase)
        : health.likelyUnreadable
        // Frames arrive but carry no readable text (canvas/Compose UI) —
        // a parser update can't fix this; it needs the OCR fallback.
        ? ('Unreadable · OCR needed', VerdictColors.bad, VerdictColors.badBg)
        : health.likelyBroken
        ? ('Needs update', VerdictColors.bad, VerdictColors.badBg)
        : health.parsed > 0
        ? (
            'OK · ${health.parsed} read',
            VerdictColors.good,
            VerdictColors.goodBg,
          )
        : ('No offers yet', FoxColors.textSecondary, FoxColors.bgBase);

    return Opacity(
      opacity: watched ? 1 : 0.55,
      child: Row(
        children: [
          Expanded(child: Text(app.label, style: text.titleMedium)),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm + Gap.xs,
              vertical: Gap.xs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One accordion group card: tappable header (icon chip + title + live
/// summary + chevron) over an AnimatedSize body. Single-open behavior lives
/// in the parent (`_open` index) so the page never grows unbounded.
/// A live "$24.50" sample in each MoneyFont, tappable to select it app-wide.
class _FontChoiceCard extends StatelessWidget {
  const _FontChoiceCard({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final MoneyFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + Gap.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? FoxColors.brandFoxSoft : FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.field),
          border: Border.all(
            color: selected
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r'$24.50',
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: FoxColors.cream,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    font.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FoxColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: FoxColors.brandFox,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.summary,
    required this.open,
    required this.onTap,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String summary;
  final bool open;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: open ? FoxColors.border : FoxColors.borderSoft,
        ),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: open
                          ? FoxColors.brandFoxSoft
                          : FoxColors.bgSurface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: open
                          ? FoxColors.brandFox
                          : FoxColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: FoxColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.base,
                    curve: Motion.curve,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: FoxColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // AnimatedSize animates the height change; the body is conditionally
          // built, so collapsing discards the group's child state (deliberate —
          // groups are cheap to rebuild).
          AnimatedSize(
            duration: Motion.morph,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md,
                      0,
                      Gap.md,
                      Gap.md,
                    ),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A horizontal bar split into BAD / OK / GOOD zones at the current cut points.
class _ThresholdBand extends StatelessWidget {
  const _ThresholdBand({
    required this.thresholds,
    required this.min,
    required this.max,
    required this.unit,
  });

  final Thresholds thresholds;
  final double min;
  final double max;
  final String unit;

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
                    child: const ColoredBox(color: VerdictColors.bad),
                  ),
                if (okFlex > 0)
                  Expanded(
                    flex: okFlex,
                    child: const ColoredBox(color: VerdictColors.ok),
                  ),
                if (goodFlex > 0)
                  Expanded(
                    flex: goodFlex,
                    child: const ColoredBox(color: VerdictColors.good),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\$${min.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            // Cut points, so the band and the sliders visibly connect.
            Text(
              '\$${thresholds.badBelow.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VerdictColors.bad.withValues(alpha: 0.85),
              ),
            ),
            Text(
              '\$${thresholds.goodAtOrAbove.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VerdictColors.good.withValues(alpha: 0.85),
              ),
            ),
            Text(
              '\$${max.toStringAsFixed(2)}$unit',
              style: Theme.of(context).textTheme.labelSmall,
            ),
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
                fontSize: 13.5,
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

    return Column(
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
    );
  }
}

/// Driver name with an explicit save; the check button appears only while the
/// draft differs from the stored name (spec M6 §4.2 — no silent live-apply).
class _DriverNameCard extends ConsumerStatefulWidget {
  const _DriverNameCard();

  @override
  ConsumerState<_DriverNameCard> createState() => _DriverNameCardState();
}

class _DriverNameCardState extends ConsumerState<_DriverNameCard> {
  late final _name = TextEditingController();
  bool _seeded = false;
  bool _editing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(driverNameProvider.notifier).setName(_name.text.trim());
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(driverNameProvider);
    // Seed once from the async-loaded name — after that the field owns its text.
    if (!_seeded && saved.isNotEmpty) {
      _name.text = saved;
      _seeded = true;
    }
    final dirty = _name.text.trim() != saved.trim();

    // Two modes (device feedback 2026-07-20 — a saved name should not look
    // permanently editable): display row (name + pencil) ↔ edit row
    // (TextField + Save while dirty). Empty saved name starts in edit mode
    // so first-run still has an obvious field.
    if (!_editing && saved.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(saved, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('edit-name'),
            onPressed: () => setState(() {
              _name.text = saved; // discard any stale draft
              _editing = true;
            }),
            icon: const Icon(
              Icons.edit_outlined,
              color: FoxColors.textSecondary,
              size: 18,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            autofocus: _editing, // pencil tap → keyboard up immediately
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            // Greeting shows this name — cap it so it can't dominate Home.
            maxLength: 20,
            onSubmitted: (_) {
              if (_name.text.trim() != saved.trim()) {
                _save();
              } else {
                setState(() => _editing = false);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Name',
              isDense: true,
              counterText: '',
            ),
          ),
        ),
        if (dirty) ...[
          const SizedBox(width: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('save-name'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: FoxColors.brandFox,
              foregroundColor: Colors.white,
              // Theme default is Size.fromHeight(52) → infinite width, which
              // can't sit in this Row next to the field.
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.field),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

/// Vehicle list — premium mini car-cards + a "+ Add vehicle" affordance (spec
/// M6 §4.2). Tap sets active (instant, persisted). The edit icon opens the
/// editor.
class _GarageList extends ConsumerWidget {
  const _GarageList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    return Column(
      children: [
        for (final v in garage.vehicles) ...[
          _VehicleCard(
            vehicle: v,
            active: garage.active?.id == v.id,
            onTap: () => ref.read(garageProvider.notifier).setActive(v.id),
            onEdit: () => context.push('/vehicle-editor', extra: v),
          ),
          const SizedBox(height: Gap.sm),
        ],
        // "+ Add vehicle" card.
        InkWell(
          key: const ValueKey('add-vehicle'),
          borderRadius: BorderRadius.circular(Radii.cardSm),
          onTap: () => context.push('/vehicle-editor'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.cardSm),
              border: Border.all(color: FoxColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: FoxColors.brandFox, size: 20),
                SizedBox(width: Gap.sm),
                Text(
                  'Add vehicle',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.brandFox,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One vehicle row: art thumbnail, title + plate chip, active tick, edit icon.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.active,
    required this.onTap,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.cardSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Gap.sm + Gap.xs),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(
            color: active ? FoxColors.brandFox : FoxColors.borderSoft,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? Shadows.glowSoft : Shadows.soft,
        ),
        child: Row(
          children: [
            VehicleBadge(
              bodyType: vehicle.bodyType,
              color: Color(vehicle.colorValue),
              fuelType: vehicle.fuelType,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.title.isEmpty ? 'Unnamed vehicle' : vehicle.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FoxColors.textPrimary,
                    ),
                  ),
                  if (vehicle.plate.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: FoxColors.bgSurface2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: FoxColors.border),
                      ),
                      child: Text(
                        vehicle.plate,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: FoxColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle_rounded,
                color: FoxColors.brandFox,
                size: 20,
              ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                color: FoxColors.textSecondary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "How to read the pill" legend under the live preview — a quick walkthrough
/// for new installs. Each row = one colored key + what it means, mirroring the
/// sample pill exactly (verdict block, green/red pickup km, $/hr).
class _PillLegend extends StatelessWidget {
  const _PillLegend();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(Color dot, String label, String meaning) => Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label — ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: FoxColors.cream,
                    ),
                  ),
                  TextSpan(text: meaning),
                ],
              ),
              style: text.bodyMedium?.copyWith(color: FoxColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to read it',
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: FoxColors.cream,
          ),
        ),
        row(
          const Color(0xFF39A96C),
          '\$/km block',
          'the verdict. Green GOOD, amber OK, red BAD — take it in a glance.',
        ),
        row(
          const Color(0xFF5ECD90),
          'Green km',
          'pickup is within your pickup radius (set below).',
        ),
        row(
          const Color(0xFFFF8A7E),
          'Red km',
          'pickup is beyond your radius — you drive further for free.',
        ),
        row(
          FoxColors.creamDim,
          '\$/hr',
          'payout over the full trip time, so long rides don\'t fool you.',
        ),
      ],
    );
  }
}
