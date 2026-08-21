import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/app_skin.dart';
import '../../domain/app_text_size.dart';
import '../../domain/app_currency.dart';
import '../../domain/bubble_style.dart';
import '../../domain/distance_unit.dart';
import '../../domain/fox_settings.dart';
import '../../domain/money_font.dart';
import '../../domain/overlay_payload.dart' show OverlayPayload, PillSize;
import '../../parser/parser_registry.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../../services/parse_health.dart';
import '../overlay/verdict_pill.dart';
import '../legal/ocr_disclosure.dart';
import '../shell/root_shell.dart';
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

/// RFC 4180-style CSV cell escaping plus a spreadsheet formula guard for text
/// imported from driver apps.
String csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (text.isNotEmpty && '=+-@'.contains(text[0])) text = "'$text";
  if (text.contains(RegExp(r'[",\r\n]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// Account, appearance, diagnostics, history, and app-level preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Muted per-group accents; green/red remain reserved for verdicts.
  static List<Color> get _accents => [
    FoxColors.brandFox, // 0 Profile — brand orange
    const Color(0xFFE8B44F), // 1 Garage — amber
    const Color(0xFF6ABF9E), // 2 Parser health — mint
    const Color(0xFFEF7BA8), // 3 Outcome tracking — rose
    const Color(0xFFD08954), // 4 Pill size — copper
    const Color(0xFF7F9FB8), // 5 Text size — blue gray
    const Color(0xFFC8C87A), // 6 Appearance — olive gold
    const Color(0xFF9AA7B8), // 7 History — slate
    FoxColors.brandFox,
  ];

  /// Single-open accordion index (-1 = all collapsed).
  int _open = -1;
  bool _bubbleStylesOpen = false;
  void _toggle(int i) => setState(() => _open = _open == i ? -1 : i);

  Future<void> _setOcrEnabled(bool enabled) async {
    if (!enabled) {
      ref.read(settingsProvider.notifier).setOcrEnabled(false);
      return;
    }
    if (!await showOcrDisclosure(context) || !mounted) return;
    ref.read(settingsProvider.notifier).setOcrEnabled(true);
  }

  /// One key per row so a deep link can scroll its target into view. The rows
  /// all live in a plain `ListView(children:)`, so anything past the cache
  /// extent has no context to scroll to — hence the null guard rather than a
  /// bang. Worst case the group is open but the driver still has to scroll,
  /// which is where every deep link used to land.
  final _rowKeys = List.generate(9, (_) => GlobalKey());

  /// Honour a jump made with `TabIndex.go(3, section: n)`: expand the group the
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
      if (next == 3) _consumeDeepLink();
    });

    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;
    final garage = ref.watch(garageProvider);
    final reminders = ref.watch(reminderProvider);
    final driverName = ref.watch(driverNameProvider);

    return ListView(
      key: const Key('settings_scroll'),
      // 100 clears the floating nav; add the gesture-bar inset like Home does
      // (fixed 100 clipped the last card on gesture-nav phones).
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        Gap.sm,
        Gap.md,
        112 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Text('Settings', style: text.headlineMedium),
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
        const SectionLabel('App health'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          2,
          SettingsGroup(
            title: 'Offer detection',
            icon: Icons.monitor_heart_outlined,
            summary: settings.ocrEnabled
                ? 'Current session · OCR enabled'
                : 'Current session',
            open: _open == 2,
            accent: _accents[2],
            onTap: () => _toggle(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    for (final app in ParserRegistry.supportedPlatforms) ...[
                      HealthRow(
                        app: app,
                        watched: settings.watches(app),
                        health:
                            ref.watch(parseHealthProvider)[app] ??
                            const PlatformHealth(),
                      ),
                      if (app != ParserRegistry.supportedPlatforms.last)
                        Divider(color: FoxColors.border, height: Gap.lg),
                    ],
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Current session. If offer cards arrive but FoxyCo cannot '
                  'read them, update the app or enable the screen-reading fallback.',
                  style: text.bodyMedium?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                Divider(color: FoxColors.border, height: Gap.xl),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.document_scanner_outlined,
                      color: FoxColors.brandFox,
                    ),
                    title: Text(
                      'Screen-reading fallback',
                      style: text.titleMedium,
                    ),
                    subtitle: const Text(
                      'Uses on-device OCR when Accessibility cannot read a card',
                    ),
                    value: settings.ocrEnabled,
                    activeTrackColor: FoxColors.brandFox,
                    onChanged: _setOcrEnabled,
                  ),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('How detection works'),
                  children: [
                    Text(
                      'Accessibility stays primary. On Android 11 and newer, '
                      'FoxyCo can take one screenshot only when a readable '
                      'offer frame is missing. Recognition stays on-device; '
                      'screenshots are never saved. "Needs update" usually '
                      'means the app layout changed.',
                      style: text.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                    if (kDebugMode) ...[
                      Divider(color: FoxColors.border, height: Gap.xl),
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          key: const Key('ocr_test_mode_toggle'),
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.science_outlined,
                            color: FoxColors.brandFox,
                          ),
                          title: Text(
                            'Force OCR test mode',
                            style: text.titleMedium,
                          ),
                          subtitle: const Text(
                            'Debug only · bypasses Accessibility text for testing',
                          ),
                          value: settings.ocrTestMode,
                          activeTrackColor: FoxColors.brandFox,
                          onChanged: settings.ocrEnabled
                              ? controller.setOcrTestMode
                              : null,
                        ),
                      ),
                      Text(
                        'Accessibility remains enabled because its active-app '
                        'events trigger each screenshot. This mode resets '
                        'after an app restart and is unavailable in release '
                        'builds.',
                        style: text.bodyMedium?.copyWith(
                          fontSize: 12,
                          height: 1.45,
                          color: FoxColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          3,
          SettingsGroup(
            title: 'Outcome tracking',
            icon: Icons.fact_check_outlined,
            summary: settings.trackOutcomes ? 'On' : 'Off',
            open: _open == 3,
            accent: _accents[3],
            onTap: () => _toggle(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Auto-detect outcome', style: text.titleMedium),
                    value: settings.trackOutcomes,
                    activeTrackColor: FoxColors.brandFox,
                    onChanged: controller.setTrackOutcomes,
                  ),
                ),
                const SizedBox(height: Gap.xs),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('How it works'),
                  children: [
                    Text(
                      'FoxyCo estimates whether an offer was taken or passed '
                      'from the screen that replaces it. It may occasionally '
                      'be wrong. Your corrections will not be overwritten. '
                      'FoxyCo only reads the screen; it never '
                      'taps or accepts anything for you.',
                      style: text.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Look & feel'),
        const SizedBox(height: Gap.sm + Gap.xs),
        _staggered(
          4,
          SettingsGroup(
            title: 'Pill size',
            icon: Icons.circle_outlined,
            summary: switch (settings.pillSize) {
              PillSize.small => 'Small',
              PillSize.medium => 'Medium',
              PillSize.large => 'Large',
            },
            open: _open == 4,
            accent: _accents[4],
            onTap: () => _toggle(4),
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
                      payload: OverlayPayload(
                        verdict: Verdict.good,
                        totalKm: 8.4,
                        payout: 12,
                        totalMinutes: 24,
                        rateMode: settings.rateMode,
                        pickupKm: 2.1,
                        pickupNearKm: 3,
                        hourGoodAt: 30,
                        hourBadBelow: 20,
                        distanceUnit: settings.distanceUnit,
                        currency: settings.currency,
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
                PillLegend(distanceLabel: settings.distanceUnit.shortLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        _staggered(
          5,
          SettingsGroup(
            title: 'Text size',
            icon: Icons.format_size_rounded,
            summary: settings.appTextSize.label,
            open: _open == 5,
            accent: _accents[5],
            onTap: () => _toggle(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceRow<AppTextSize>(
                  values: AppTextSize.values,
                  selected: settings.appTextSize,
                  labelOf: (size) => size.label,
                  onChanged: controller.setAppTextSize,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Changes FoxyCo screens only. The floating offer pill keeps '
                  'its separate Pill size setting.',
                  style: text.bodySmall?.copyWith(
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
            title: 'Appearance',
            icon: Icons.text_fields_rounded,
            summary:
                '${settings.bubbleStyle.label} · ${settings.skin.label} · '
                '${settings.distanceUnit.shortLabel} · ${settings.currency.label}',
            open: _open == 6,
            accent: _accents[6],
            onTap: () => _toggle(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BubbleStyleRow(
                  style: settings.bubbleStyle,
                  expanded: _bubbleStylesOpen,
                  onTap: () =>
                      setState(() => _bubbleStylesOpen = !_bubbleStylesOpen),
                ),
                if (_bubbleStylesOpen) ...[
                  const SizedBox(height: Gap.xs),
                  _BubbleStyleChoices(
                    selected: settings.bubbleStyle,
                    onSelected: controller.setBubbleStyle,
                  ),
                ],
                const SizedBox(height: Gap.md),
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
                Text('Distance', style: text.titleSmall),
                const SizedBox(height: Gap.sm),
                ChoiceRow<DistanceUnit>(
                  values: DistanceUnit.values,
                  selected: settings.distanceUnit,
                  labelOf: (unit) => unit.label,
                  onChanged: controller.setDistanceUnit,
                ),
                const SizedBox(height: Gap.lg),
                Text('Offer currency', style: text.titleSmall),
                const SizedBox(height: Gap.sm),
                ChoiceRow<AppCurrency>(
                  values: AppCurrency.values.take(3).toList(),
                  selected: settings.currency,
                  labelOf: (currency) => currency.label,
                  onChanged: controller.setCurrency,
                ),
                const SizedBox(height: Gap.sm),
                ChoiceRow<AppCurrency>(
                  values: AppCurrency.values.skip(3).toList(),
                  selected: settings.currency,
                  labelOf: (currency) => currency.label,
                  onChanged: controller.setCurrency,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'USD defaults to miles; all other options default to '
                  'kilometres. You can override Distance above. FoxyCo labels '
                  'fares as reported and does not convert them.',
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
          7,
          SettingsGroup(
            title: 'History',
            icon: Icons.history_rounded,
            summary: settings.retentionDays == FoxSettings.keepForever
                ? 'Keep forever'
                : 'Keep ${settings.retentionDays} days',
            open: _open == 7,
            accent: _accents[7],
            onTap: () => _toggle(7),
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
                Column(
                  key: const Key('history_actions'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: Gap.xs),
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
        const SizedBox(height: Gap.sm),
        TextButton.icon(
          onPressed: () => _confirmReset(context, controller),
          style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text(
            'Reset preferences',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: Gap.lg),
        const SectionLabel('Help & support'),
        const SizedBox(height: Gap.sm + Gap.xs),
        // Support actions stay together and remain compact link rows: feedback
        // for testers, self-serve help, then advanced diagnostic logs.
        _staggered(
          8,
          const LinkRow(
            icon: Icons.rate_review_outlined,
            title: 'Send feedback',
            trailing: 'Describe a problem',
            route: '/feedback',
          ),
        ),
        const SizedBox(height: Gap.sm),
        const LinkRow(
          icon: Icons.info_outline_rounded,
          title: 'Help & About',
          trailing: aboutVersion,
          route: '/about',
        ),
        const SizedBox(height: Gap.sm),
        const LinkRow(
          icon: Icons.receipt_long_outlined,
          title: 'Diagnostic logs',
          trailing: 'Troubleshooting details',
          route: '/logs',
        ),
      ],
    );
  }

  /// Section-entry stagger (spec M6 §6): each section fades + slides up with a
  /// small per-index delay. Reduced-motion or below-the-fold sections render
  /// instantly — no loops, no jank.
  ///
  /// Only the first six groups animate; below-the-fold rows render instantly.
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
    final settings = ref.read(settingsProvider);
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
      'seen_at,app,category,queued,orders,items,units,verdict,currency,fare,bonus,distance_unit,total_distance,pickup_distance,minutes,rate_per_distance,per_hour,outcome\n',
    );
    for (final o in offers) {
      buf.writeln(
        [
          o.seenAt.toIso8601String(),
          o.platform.label,
          o.category ?? '',
          o.isQueued,
          o.deliveryCount,
          o.itemCount,
          o.unitCount,
          o.verdict.name,
          settings.currency.label,
          o.payout.toStringAsFixed(2),
          o.bonus.toStringAsFixed(2),
          settings.distanceUnit.shortLabel,
          settings.distanceUnit.distanceFromKm(o.totalKm).toStringAsFixed(1),
          settings.distanceUnit.distanceFromKm(o.pickupKm).toStringAsFixed(1),
          o.totalMinutes.toStringAsFixed(0),
          settings.distanceUnit.rateFromPerKm(o.pricePerKm).toStringAsFixed(2),
          o.pricePerHour.toStringAsFixed(2),
          o.outcome.name,
        ].map(csvCell).join(','),
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
        title: const Text('Reset preferences?'),
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
            child: const Text('Reset preferences'),
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

class _BubbleStyleRow extends StatelessWidget {
  const _BubbleStyleRow({
    required this.style,
    required this.expanded,
    required this.onTap,
  });

  final BubbleStyle style;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    expanded: expanded,
    label: 'Floating bubble, ${style.label}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Floating bubble', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Icon shown over apps',
          style: TextStyle(fontSize: 12, color: FoxColors.textSecondary),
        ),
        const SizedBox(height: Gap.xs),
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: FoxColors.bgSurface2,
              borderRadius: BorderRadius.circular(Radii.cardSm),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            child: InkWell(
              key: const Key('settings-bubble-style-control'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.cardSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: Gap.xs,
                  ),
                  child: Row(
                    children: [
                      _BubblePreview(style: style, size: 34),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          style.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: FoxColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.xs),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: Motion.base,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: FoxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BubbleStyleChoices extends StatelessWidget {
  const _BubbleStyleChoices({required this.selected, required this.onSelected});

  final BubbleStyle selected;
  final ValueChanged<BubbleStyle> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final style in BubbleStyle.values) ...[
        Expanded(
          child: _BubbleStyleOption(
            style: style,
            selected: style == selected,
            onTap: () => onSelected(style),
          ),
        ),
        if (style != BubbleStyle.values.last) const SizedBox(width: Gap.sm),
      ],
    ],
  );
}

class _BubbleStyleOption extends StatelessWidget {
  const _BubbleStyleOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final BubbleStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: style.label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.cardSm),
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xs,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? FoxColors.brandFox.withValues(alpha: 0.08)
              : FoxColors.bgSurface2,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(
            color: selected
                ? FoxColors.brandFox.withValues(alpha: 0.75)
                : FoxColors.borderSoft,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BubblePreview(style: style, size: 48),
            const SizedBox(height: Gap.xs),
            Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? FoxColors.textPrimary
                    : FoxColors.textSecondary,
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 14, color: FoxColors.brandFox),
          ],
        ),
      ),
    ),
  );
}

class _BubblePreview extends StatelessWidget {
  const _BubblePreview({required this.style, required this.size});

  final BubbleStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      style.assetPath,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      semanticLabel: style.label,
    ),
  );
}
