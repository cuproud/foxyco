import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/app_skin.dart';
import '../../domain/decision_engine.dart';
import '../../domain/fox_settings.dart';
import '../../domain/money_font.dart';
import '../../domain/overlay_payload.dart' show OverlayPayload, PillSize;
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/verdict.dart';
import '../../services/billing/entitlement.dart';
import '../../services/offer_log.dart';
import '../../services/parse_health.dart';
import '../overlay/verdict_pill.dart';
import '../paywall/unlock_section.dart';
import '../shell/root_shell.dart';
import '../theme/platform_badge.dart';
import '../theme/section_label.dart';
import '../theme/tokens.dart';
import 'about_content.dart';
import 'garage_controller.dart';
import 'garage_section.dart';
import 'profile_section.dart';
import 'reminder_controller.dart';
import 'reminder_section.dart';
import 'settings_controller.dart';
import 'settings_controls.dart';

/// Settings — every driver-tunable knob in [FoxSettings]: verdict thresholds
/// (with live preview), pickup-distance guard, watched apps, pill size, theme +
/// money font, and history retention / clear.
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

  /// Per-group accent hues, index-matched to the GROUP INDEX rather than the
  /// on-screen order (Parser health, 9, is shown up with Watched apps) — flat
  /// same-orange tiles read boring (device 2026-07-21). Muted; green/red stay
  /// reserved for verdicts except the thresholds group, whose whole point is
  /// the verdict band.
  ///
  /// A getter, not a `const` list: the verdict green below is theme-varying, so
  /// the list has to be rebuilt after a palette switch.
  static List<Color> get _accents => [
    FoxColors.brandFox, // 0 Profile — brand orange
    const Color(0xFFE8B44F), // 1 Garage — amber
    VerdictColors.good, // 2 Verdict thresholds — the band's green
    const Color(0xFF5EC2CD), // 3 Live preview — teal
    const Color(0xFF4FA3E8), // 4 Pickup guard — blue
    const Color(0xFFB48AE8), // 5 Watched apps — violet
    const Color(0xFFEF7BA8), // 6 Outcome tracking — rose
    const Color(0xFFD08954), // 7 Pill size — copper
    const Color(0xFFC8C87A), // 8 Appearance — olive gold
    const Color(0xFF6ABF9E), // 9 Parser health — mint
    const Color(0xFF9AA7B8), // 10 History — slate
    // 11 Unlock — brand orange, same as Driver. Deliberate: this is the one
    // group that IS the brand action, and the two sit at opposite ends of a
    // long list, so they never read as a repeated tile.
    FoxColors.brandFox,
  ];

  /// Live-preview sample rate, one per mode so flipping modes lands on a
  /// sensible sample instead of an out-of-range one.
  double _samplePpk = 1.25;
  double _samplePph = 25.0;

  /// Single-open accordion index (-1 = all collapsed); Profile open by default.
  int _open = 0;
  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);

  /// One key per row so a deep link can scroll its target into view. The rows
  /// all live in a plain `ListView(children:)`, so anything past the cache
  /// extent has no context to scroll to — hence the null guard rather than a
  /// bang. Worst case the group is open but the driver still has to scroll,
  /// which is where every deep link used to land.
  final _rowKeys = List.generate(13, (_) => GlobalKey());

  /// Honour a jump made with `TabIndex.go(2, section: n)`: expand the group the
  /// driver actually tapped for and bring it on screen. Consumed once, so
  /// switching to Settings by hand afterwards leaves their accordion alone.
  void _consumeDeepLink() {
    final tabs = ref.read(tabIndexProvider.notifier);
    final target = tabs.pendingSection;
    if (target == null) return;
    tabs.pendingSection = null;
    setState(() => _open = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for the previously-open group to collapse and the target to grow.
      // Scrolling against their old heights overshoots once Profile contains
      // account details, leaving the requested header above the viewport.
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
    // Settings is always built (it's an IndexedStack child), so the deep link
    // has to hang off the tab CHANGE, not off this build.
    ref.listen<int>(tabIndexProvider, (_, next) {
      if (next == 2) _consumeDeepLink();
    });

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
        const SectionLabel('You & your car'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          0,
          SettingsGroup(
            title: 'Profile',
            icon: Icons.person_outline_rounded,
            summary: driverName.isNotEmpty ? driverName : 'Set your name',
            open: _open == 0,
            accent: _accents[0],
            onTap: () => _toggle(0),
            child: const ProfileSection(),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          1,
          SettingsGroup(
            title: 'Garage',
            icon: Icons.garage_outlined,
            summary:
                '${garage.vehicles.length} vehicle'
                '${garage.vehicles.length == 1 ? '' : 's'} · '
                '${reminders.length} reminder'
                '${reminders.length == 1 ? '' : 's'}',
            open: _open == 1,
            accent: _accents[1],
            onTap: () => _toggle(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GarageList(),
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Icon(
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
        const SizedBox(height: Gap.lg),
        const SectionLabel('Scoring'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          2,
          SettingsGroup(
            title: 'Verdict thresholds',
            icon: Icons.tune_rounded,
            summary: 'GOOD ≥ \$${t.goodAtOrAbove.toStringAsFixed(2)}$unit',
            open: _open == 2,
            accent: _accents[2],
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
                      selectedForegroundColor: FoxColors.textPrimary,
                      foregroundColor: FoxColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                // One-tap starting points (same trio as onboarding).
                // Only shown in $/km mode — the presets are $/km numbers.
                if (!perHour) ...[
                  PresetChips(current: t, onPick: controller.applyPreset),
                  const SizedBox(height: Gap.md),
                ],
                ThresholdBand(thresholds: t, min: min, max: max, unit: unit),
                const SizedBox(height: Gap.md),
                ThresholdSlider(
                  label: 'GOOD at or above',
                  color: VerdictColors.good,
                  value: t.goodAtOrAbove,
                  min: min,
                  max: max,
                  onChanged: controller.setGood,
                ),
                const SizedBox(height: Gap.md),
                ThresholdSlider(
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
          SettingsGroup(
            title: 'Live preview',
            icon: Icons.visibility_outlined,
            summary: 'Try a sample rate',
            open: _open == 3,
            accent: _accents[3],
            onTap: () => _toggle(3),
            child: PreviewCard(
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
          SettingsGroup(
            title: 'Pickup guard',
            icon: Icons.near_me_outlined,
            summary: 'Near ≤ ${settings.pickupNearKm.toStringAsFixed(1)} km',
            open: _open == 4,
            accent: _accents[4],
            onTap: () => _toggle(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThresholdSlider(
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
        const SizedBox(height: Gap.lg),
        const SectionLabel('Watching'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          5,
          SettingsGroup(
            title: 'Watched apps',
            icon: Icons.apps_rounded,
            summary: settings.watchedApps.map((a) => a.label).join(' · '),
            open: _open == 5,
            accent: _accents[5],
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
                      Divider(color: FoxColors.border, height: 1),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          9,
          SettingsGroup(
            title: 'Parser health',
            icon: Icons.monitor_heart_outlined,
            summary: 'This session',
            open: _open == 9,
            accent: _accents[9],
            onTap: () => _toggle(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    for (final app in GigPlatform.values) ...[
                      HealthRow(
                        app: app,
                        watched: settings.watches(app),
                        health:
                            ref.watch(parseHealthProvider)[app] ??
                            const PlatformHealth(),
                      ),
                      if (app != GigPlatform.values.last)
                        Divider(color: FoxColors.border, height: Gap.lg),
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
          6,
          SettingsGroup(
            title: 'Outcome tracking',
            icon: Icons.fact_check_outlined,
            summary: settings.trackOutcomes ? 'On' : 'Off',
            open: _open == 6,
            accent: _accents[6],
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
        const SizedBox(height: Gap.lg),
        const SectionLabel('Look & feel'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          7,
          SettingsGroup(
            title: 'Pill size',
            icon: Icons.circle_outlined,
            summary: switch (settings.pillSize) {
              PillSize.small => 'Small',
              PillSize.medium => 'Medium',
              PillSize.large => 'Large',
            },
            open: _open == 7,
            accent: _accents[7],
            onTap: () => _toggle(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceRow<PillSize>(
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
                        hourGoodAt: 30,
                        hourBadBelow: 20,
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
                const PillLegend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          8,
          SettingsGroup(
            title: 'Appearance',
            icon: Icons.text_fields_rounded,
            summary: '${settings.skin.label} · ${settings.moneyFont.label}',
            open: _open == 8,
            accent: _accents[8],
            onTap: () => _toggle(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Theme',
                  style: text.titleSmall?.copyWith(
                    color: FoxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                ChoiceRow<AppSkin>(
                  values: AppSkin.values,
                  selected: settings.skin,
                  labelOf: (s) => s.label,
                  onChanged: controller.setSkin,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  settings.skin.blurb,
                  style: text.bodySmall?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  'Money numbers',
                  style: text.titleSmall?.copyWith(
                    color: FoxColors.textPrimary,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Typeface for the big money numbers — pill, home and '
                  'history.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.md),
                for (final f in MoneyFont.values) ...[
                  FontChoiceCard(
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
        const SizedBox(height: Gap.lg),
        const SectionLabel('Your data'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          10,
          SettingsGroup(
            title: 'History',
            icon: Icons.history_rounded,
            summary: settings.retentionDays == FoxSettings.keepForever
                ? 'Keep forever'
                : 'Keep ${settings.retentionDays} days',
            open: _open == 10,
            accent: _accents[10],
            onTap: () => _toggle(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep offers for', style: text.titleMedium),
                const SizedBox(height: Gap.sm),
                ChoiceRow<int>(
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
                Divider(color: FoxColors.border, height: Gap.xl),
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
        const SizedBox(height: Gap.lg),
        const SectionLabel('Your unlock'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          11,
          SettingsGroup(
            title: 'Unlock',
            icon: Icons.lock_open_rounded,
            summary: UnlockSection.summaryOf(ref.watch(accessProvider)),
            open: _open == 11,
            accent: _accents[11],
            onTap: () => _toggle(11),
            child: const UnlockSection(),
          ),
        ),
        const SizedBox(height: Gap.sm),
        // Last two rows, plain links rather than accordions — these are pages,
        // not groups of knobs. Logs is the record About tells drivers to check
        // when the watcher goes quiet ("Settings → Logs"); it had a screen and
        // a test but no route and no way in, so that instruction pointed at
        // nothing.
        _staggered(
          12,
          const LinkRow(
            icon: Icons.info_outline_rounded,
            title: 'About & help',
            trailing: aboutVersion,
            route: '/about',
          ),
        ),
        const SizedBox(height: Gap.sm),
        const LinkRow(
          icon: Icons.receipt_long_outlined,
          title: 'Logs',
          trailing: 'Watcher record',
          route: '/logs',
        ),
      ],
    );
  }

  /// Section-entry stagger (spec M6 §6): each section fades + slides up with a
  /// small per-index delay. Reduced-motion or below-the-fold sections render
  /// instantly — no loops, no jank.
  ///
  /// Cutoff is 5, not the old 7: the delay is derived from the group INDEX, and
  /// only the first six groups still appear in index order on screen (Parser
  /// health, 9, was lifted up into the Watching band). Past that the two
  /// disagree, and a stagger that runs out of step with the page reads as jitter
  /// — below the fold nobody was going to see it anyway.
  Widget _staggered(int i, Widget child) {
    // Keyed here rather than at every call site — it's the one wrapper every
    // row already goes through.
    child = KeyedSubtree(key: _rowKeys[i], child: child);
    if (MediaQuery.of(context).disableAnimations || i > 5) return child;
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
