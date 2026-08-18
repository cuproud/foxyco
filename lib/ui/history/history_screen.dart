import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../../parser/parser_registry.dart';
import '../settings/settings_controller.dart';
import '../theme/platform_badge.dart';
import '../theme/outcome_style.dart';
import '../theme/section_label.dart';
import '../theme/step_button.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'offer_detail_sheet.dart';

/// History (references/foxyco_history.html).
///
/// Time range + app, verdict and trip-status filters + a "top offers only"
/// filter over the live offer log ([offerLogProvider]) — every scored offer
/// FoxyCo has seen.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  /// Header count label — FILTERED count, range named (spec M6 §5.1: the old
  /// header showed all.length while the list showed Today; post-midnight
  /// that read "22 offers" over an empty list).
  static String headerLabel(int filteredCount, HistoryRange range) =>
      switch (range) {
        HistoryRange.today => '$filteredCount today',
        HistoryRange.week => '$filteredCount in 7 days',
        HistoryRange.month => '$filteredCount in 30 days',
        HistoryRange.all => '$filteredCount all time',
      };

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum HistoryRange { today, week, month, all }

enum HistoryOutcomeFilter {
  all,
  accepted,
  declined,
  cancelled,
  completed,
  unknown,
}

String _outcomeLabel(HistoryOutcomeFilter value) => switch (value) {
  HistoryOutcomeFilter.all => 'All outcomes',
  HistoryOutcomeFilter.accepted => 'Accepted',
  HistoryOutcomeFilter.declined => 'Not taken',
  HistoryOutcomeFilter.cancelled => 'Cancelled',
  HistoryOutcomeFilter.completed => 'Completed',
  HistoryOutcomeFilter.unknown => 'Unknown',
};

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryRange _range = HistoryRange.today;
  final Set<GigPlatform?> _apps = {null}; // null == "All"
  final Set<Verdict?> _verdicts = {null}; // null == "All"
  HistoryOutcomeFilter _outcome = HistoryOutcomeFilter.all;
  bool _filtersExpanded = false;
  bool _topOnly = false;
  int _minFare = 20;

  int _daysAgo(DateTime t) =>
      DateTime.now().difference(DateTime(t.year, t.month, t.day)).inDays;

  bool _passes(OfferSummary o) {
    final d = _daysAgo(o.seenAt);
    switch (_range) {
      case HistoryRange.today:
        if (d != 0) return false;
      case HistoryRange.week:
        if (d >= 7) return false; // today + 6 prior days = 7
      case HistoryRange.month:
        if (d >= 30) return false;
      case HistoryRange.all:
        break;
    }
    if (!_apps.contains(null) && !_apps.contains(o.platform)) return false;
    if (!_verdicts.contains(null) && !_verdicts.contains(o.verdict)) {
      return false;
    }
    final outcomeMatches = switch (_outcome) {
      HistoryOutcomeFilter.all => true,
      HistoryOutcomeFilter.accepted => o.outcome == OfferOutcome.taken,
      HistoryOutcomeFilter.declined => o.outcome == OfferOutcome.missed,
      HistoryOutcomeFilter.cancelled => o.outcome == OfferOutcome.cancelled,
      HistoryOutcomeFilter.completed => o.outcome == OfferOutcome.completed,
      HistoryOutcomeFilter.unknown => o.outcome == OfferOutcome.unknown,
    };
    if (!outcomeMatches) return false;
    // Top-only is a FARE floor, nothing more. It used to also require
    // verdict == GOOD, which read as "filter broken": raise the fare and a
    // $22 OK offer silently vanished (device 2026-07-19). Verdict now has its
    // own chips above.
    if (_topOnly && o.payout < _minFare) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(offerLogProvider);
    final availableApps = <GigPlatform>{
      ...ParserRegistry.supportedPlatforms.where(
        ref.read(settingsProvider).watches,
      ),
      ...all.map((offer) => offer.platform),
    }.toList();
    availableApps.sort(
      (a, b) => ParserRegistry.supportedPlatforms
          .indexOf(a)
          .compareTo(ParserRegistry.supportedPlatforms.indexOf(b)),
    );
    final filtered = all.where(_passes).toList()
      ..sort(
        (a, b) => _topOnly
            ? b.pricePerKm.compareTo(a.pricePerKm)
            : b.seenAt.compareTo(a.seenAt),
      );
    final stats = OfferStats.from(filtered);

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
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('History', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            Text(
              HistoryScreen.headerLabel(stats.total, _range),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FoxColors.textDisabled,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _FiltersCard(
          expanded: _filtersExpanded,
          range: _range,
          apps: _apps,
          verdicts: _verdicts,
          availableApps: availableApps,
          outcome: _outcome,
          topOnly: _topOnly,
          minFare: _minFare,
          matchCount: stats.total,
          onRange: (range) => setState(() {
            _range = range;
            if (range == HistoryRange.all) _resetFilters();
          }),
          onApp: _toggleApp,
          onVerdict: _toggleVerdict,
          onOutcome: (outcome) => setState(() => _outcome = outcome),
          onTopToggle: () => setState(() => _topOnly = !_topOnly),
          onFare: (d) =>
              setState(() => _minFare = (_minFare + d).clamp(0, 100)),
          onReset: () => setState(_resetFilters),
          onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
        ),
        const SizedBox(height: Gap.md),
        const SizedBox(height: Gap.lg),
        if (filtered.isEmpty)
          _Empty(
            hiddenCount: all.length,
            onShowAll: all.isEmpty ? null : () => setState(_resetFilters),
          )
        else ...[
          _StatsCard(stats: stats),
          const SizedBox(height: Gap.sm),
          _HourlyChart(offers: filtered),
          const SizedBox(height: Gap.sm),
          _AppVerdictChart(offers: filtered),
          const SizedBox(height: Gap.lg),
          ..._grouped(filtered),
        ],
      ],
    );
  }

  void _toggleApp(GigPlatform? app) {
    setState(() => _toggleIn(_apps, app));
  }

  void _toggleVerdict(Verdict? v) {
    setState(() => _toggleIn(_verdicts, v));
  }

  void _resetFilters() {
    _range = HistoryRange.all;
    _apps
      ..clear()
      ..add(null);
    _verdicts
      ..clear()
      ..add(null);
    _outcome = HistoryOutcomeFilter.all;
    _topOnly = false;
  }

  /// Shared multi-select behavior for filter chip sets where `null` == "All":
  /// picking All clears the rest; emptying the set falls back to All.
  static void _toggleIn<T>(Set<T?> set, T? value) {
    if (value == null) {
      set
        ..clear()
        ..add(null);
      return;
    }
    set.remove(null);
    set.contains(value) ? set.remove(value) : set.add(value);
    if (set.isEmpty) set.add(null);
  }

  /// Rows with a date header before each new day (skipped while top-only, where
  /// the list is a flat best-first ranking).
  List<Widget> _grouped(List<OfferSummary> offers) {
    if (_topOnly) {
      var i = 0;
      return offers.map((o) => _row(o, i++)).toList();
    }
    final out = <Widget>[];
    String? lastLabel;
    var i = 0;
    for (final o in offers) {
      final label = _dateLabel(o.seenAt);
      if (label != lastLabel) {
        out.add(
          Padding(
            padding: EdgeInsets.only(
              top: lastLabel == null ? 0 : Gap.md,
              bottom: Gap.sm,
            ),
            child: SectionLabel(label),
          ),
        );
        lastLabel = label;
      }
      out.add(_row(o, i++));
    }
    return out;
  }

  /// Staggered entrance for the first dozen rows (spec §5.2); beyond that, or
  /// when the OS asks for reduced motion, rows appear instantly.
  Widget _row(OfferSummary o, int index) {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced || index >= 12) return _OfferRow(offer: o);
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${o.seenAt.microsecondsSinceEpoch}-${o.payout}-${o.totalKm}-$index-$_range-$_topOnly',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Motion.stagger * index,
      curve: Motion.curve,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: c),
      ),
      child: _OfferRow(offer: o),
    );
  }

  String _dateLabel(DateTime t) {
    final d = _daysAgo(t);
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }
}

/// One compact filter surface. "All" is the single reset for every dimension;
/// an empty app/verdict selection and an unselected Accepted chip mean no
/// restriction in that dimension.
class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.expanded,
    required this.range,
    required this.apps,
    required this.verdicts,
    required this.availableApps,
    required this.outcome,
    required this.topOnly,
    required this.minFare,
    required this.matchCount,
    required this.onRange,
    required this.onApp,
    required this.onVerdict,
    required this.onOutcome,
    required this.onTopToggle,
    required this.onFare,
    required this.onReset,
    required this.onToggle,
  });

  final bool expanded;
  final HistoryRange range;
  final Set<GigPlatform?> apps;
  final Set<Verdict?> verdicts;
  final List<GigPlatform> availableApps;
  final HistoryOutcomeFilter outcome;
  final bool topOnly;
  final int minFare;
  final int matchCount;
  final ValueChanged<HistoryRange> onRange;
  final ValueChanged<GigPlatform?> onApp;
  final ValueChanged<Verdict?> onVerdict;
  final ValueChanged<HistoryOutcomeFilter> onOutcome;
  final VoidCallback onTopToggle;
  final ValueChanged<int> onFare;
  final VoidCallback onReset;
  final VoidCallback onToggle;

  int get _activeCount => [
    if (!apps.contains(null)) true,
    if (!verdicts.contains(null)) true,
    if (outcome != HistoryOutcomeFilter.all) true,
    if (topOnly) true,
    if (range != HistoryRange.today && range != HistoryRange.all) true,
  ].length;

  String get _summary {
    final platform = apps.contains(null)
        ? 'All platforms'
        : apps.length == 1
        ? apps.first!.label
        : '${apps.length} platforms';
    final fare = topOnly ? '\$$minFare+ fare' : 'Any fare';
    final period = switch (range) {
      HistoryRange.today => 'Today',
      HistoryRange.week => 'Last 7 days',
      HistoryRange.month => 'Last 30 days',
      HistoryRange.all => 'All time',
    };
    final extras = <String>[
      if (!verdicts.contains(null))
        verdicts.length == 1
            ? VerdictStyle.of(verdicts.first!).label
            : '${verdicts.length} verdicts',
      if (outcome != HistoryOutcomeFilter.all) _outcomeLabel(outcome),
    ];
    return [platform, fare, period, ...extras].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: expanded ? 'Collapse filters' : 'Expand filters',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Gap.sm),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            FoxColors.brandFox.withValues(alpha: 0.22),
                            FoxColors.brandFox.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: FoxColors.brandFox,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _activeCount == 0
                                ? 'Filters'
                                : 'Filters · $_activeCount active',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: FoxColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: Motion.base,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Gap.sm),
                _RangeControl(value: range, onChanged: onRange),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _activeCount == 0 ? null : onReset,
                    child: const Text('Reset filters'),
                  ),
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                _FilterGroup(
                  label: 'APP',
                  child: _AppChips(
                    selected: apps,
                    availableApps: availableApps,
                    onToggle: onApp,
                  ),
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                _FilterGroup(
                  label: 'VERDICT & OUTCOME',
                  child: _VerdictChips(
                    selected: verdicts,
                    onToggle: onVerdict,
                    trailing: _OutcomeChip(
                      value: outcome,
                      onChanged: onOutcome,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                _FilterGroup(
                  label: 'DISPLAY',
                  child: _TopFilter(
                    on: topOnly,
                    minFare: minFare,
                    matchCount: matchCount,
                    onToggle: onTopToggle,
                    onFare: onFare,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: FoxColors.textDisabled,
          ),
        ),
        const SizedBox(height: Gap.xs),
        child,
      ],
    );
  }
}

/// Only confirmed accepted trips are included; an unconfirmed outcome must
/// never be presented as accepted.
class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.value, required this.onChanged});

  final HistoryOutcomeFilter value;
  final ValueChanged<HistoryOutcomeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != HistoryOutcomeFilter.all;
    const activeColor = FoxColors.brandFox;
    return Semantics(
      selected: active,
      button: true,
      label: 'Outcome filter',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(
            active ? HistoryOutcomeFilter.all : HistoryOutcomeFilter.accepted,
          );
        },
        onLongPress: () async {
          HapticFeedback.selectionClick();
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final topLeft = box.localToGlobal(Offset.zero);
          final chosen = await showMenu<HistoryOutcomeFilter>(
            context: context,
            position: RelativeRect.fromLTRB(
              topLeft.dx,
              topLeft.dy + box.size.height,
              topLeft.dx + box.size.width,
              0,
            ),
            items: [
              for (final option in HistoryOutcomeFilter.values)
                PopupMenuItem(
                  value: option,
                  child: Text(_outcomeLabel(option)),
                ),
            ],
          );
          if (chosen != null) onChanged(chosen);
        },
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? FoxColors.brandFoxSoft : FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: active
                  ? FoxColors.brandFox.withValues(alpha: 0.6)
                  : FoxColors.borderSoft,
            ),
            boxShadow: active ? null : Shadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 13,
                color: active ? activeColor : FoxColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                value == HistoryOutcomeFilter.all
                    ? 'Accepted'
                    : _outcomeLabel(value),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? activeColor : FoxColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sliding-indicator time segmented control.
class _RangeControl extends StatelessWidget {
  const _RangeControl({required this.value, required this.onChanged});
  final HistoryRange value;
  final ValueChanged<HistoryRange> onChanged;

  static const _labels = {
    HistoryRange.today: 'Today',
    HistoryRange.week: '7 Days',
    HistoryRange.month: '30 Days',
    HistoryRange.all: 'All',
  };

  @override
  Widget build(BuildContext context) {
    final items = HistoryRange.values;
    final index = items.indexOf(value);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.soft,
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, c) {
          final slot = c.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Curves.easeOutBack,
                left: slot * index,
                top: 0,
                bottom: 0,
                width: slot,
                child: Container(
                  decoration: BoxDecoration(
                    color: FoxColors.brandFoxSoft,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: FoxColors.brandFox.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final r in items)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(r);
                        },
                        child: Center(
                          child: Text(
                            _labels[r]!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: r == value
                                  ? FoxColors.textPrimary
                                  : FoxColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppChips extends StatelessWidget {
  const _AppChips({
    required this.selected,
    required this.availableApps,
    required this.onToggle,
  });
  final Set<GigPlatform?> selected;
  final List<GigPlatform> availableApps;
  final ValueChanged<GigPlatform?> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [for (final p in availableApps) _chip(p, p.label)],
    );
  }

  Widget _chip(GigPlatform? app, String label) {
    final active = selected.contains(app);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle(app);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? FoxColors.brandFoxSoft : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: active
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
          boxShadow: active ? null : Shadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (app != null) ...[
              PlatformBadge(platform: app, size: 16, active: active),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? FoxColors.textPrimary : FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verdict grouping chips (good / ok / bad), same multi-select + "All"
/// behavior as [_AppChips]. Icon + word, never color alone (colorblind-safe).
class _VerdictChips extends StatelessWidget {
  const _VerdictChips({
    required this.selected,
    required this.onToggle,
    required this.trailing,
  });
  final Set<Verdict?> selected;
  final ValueChanged<Verdict?> onToggle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final v in const [Verdict.good, Verdict.ok, Verdict.bad]) _chip(v),
        trailing,
      ],
    );
  }

  Widget _chip(Verdict? v) {
    final active = selected.contains(v);
    final style = v == null ? null : VerdictStyle.of(v);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle(v);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? FoxColors.brandFoxSoft : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: active
                ? FoxColors.brandFox.withValues(alpha: 0.6)
                : FoxColors.borderSoft,
          ),
          boxShadow: active ? null : Shadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (style != null) ...[
              Icon(
                style.icon,
                size: 12,
                color: active ? FoxColors.brandFox : FoxColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              style!.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? FoxColors.textPrimary : FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact display filter with a switch + fare stepper.
class _TopFilter extends StatelessWidget {
  const _TopFilter({
    required this.on,
    required this.minFare,
    required this.matchCount,
    required this.onToggle,
    required this.onFare,
  });

  final bool on;
  final int minFare;
  final int matchCount;
  final VoidCallback onToggle;
  final ValueChanged<int> onFare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top offers only',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      on
                          ? '$matchCount offers · over \$$minFare'
                          : '$matchCount offers · any fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _Switch(on: on, onTap: onToggle),
            ],
          ),
          AnimatedCrossFade(
            duration: Motion.base,
            crossFadeState: on
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Row(
                children: [
                  Text(
                    'Minimum fare',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: FoxColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  StepButton(
                    glyph: '−',
                    onTap: () => onFare(-5),
                    semanticLabel: 'Decrease minimum fare',
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '\$$minFare',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  StepButton(
                    glyph: '+',
                    onTap: () => onFare(5),
                    semanticLabel: 'Increase minimum fare',
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 48dp hit area + semantics around the 44×26 visual.
    return Semantics(
      toggled: on,
      button: true,
      label: 'Top offers only',
      child: GestureDetector(
        key: const ValueKey('history-top-toggle'),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.base,
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: on
                    ? FoxColors.brandFox
                    : FoxColors.cream.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: AnimatedAlign(
                duration: Motion.base,
                curve: Curves.easeOutBack,
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      // local thumb drop-shadow (25% black) — decorative, not Shadows.soft
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 24-bin offers-per-hour bar chart under the stats card. One series, one
/// hue (brand orange), peak bin at full strength with a direct count label —
/// selective labeling, no legend needed. Bars are plain Containers; heights
/// scale to the busiest bin.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.offers});
  final List<OfferSummary> offers;

  @override
  Widget build(BuildContext context) {
    final bins = List<int>.filled(24, 0);
    for (final o in offers) {
      bins[o.seenAt.hour]++;
    }
    final peak = bins.reduce((a, b) => a > b ? a : b);
    if (peak == 0) return const SizedBox.shrink();
    final peakHour = bins.indexOf(peak);

    const chartH = 56.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Gap.md + Gap.xs,
        Gap.md,
        Gap.md + Gap.xs,
        Gap.sm + Gap.xs,
      ),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BY HOUR', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Gap.sm),
          // Peak count sits right above its bar.
          SizedBox(
            height: chartH + 16,
            child: LayoutBuilder(
              builder: (context, c) {
                final slot = c.maxWidth / 24;
                return Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var h = 0; h < 24; h++)
                            Expanded(
                              child: Padding(
                                // 2px gap between bars (1px each side).
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Container(
                                  // Empty bins keep a 2px baseline stub so the
                                  // 24-hour axis reads as continuous.
                                  height: bins[h] == 0
                                      ? 2
                                      : (chartH * bins[h] / peak).clamp(
                                          3.0,
                                          chartH,
                                        ),
                                  decoration: BoxDecoration(
                                    color: h == peakHour
                                        ? FoxColors.brandFox
                                        : bins[h] == 0
                                        ? FoxColors.cream.withValues(
                                            alpha: 0.08,
                                          )
                                        : FoxColors.brandFox.withValues(
                                            alpha: 0.28,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Direct label on the peak only.
                    Positioned(
                      bottom: chartH + 2,
                      left: (slot * peakHour + slot / 2 - 20).clamp(
                        0.0,
                        c.maxWidth - 40,
                      ),
                      child: SizedBox(
                        width: 40,
                        child: Text(
                          '$peak',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: FoxColors.brandFox,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Gap.xs),
          // Sparse hour axis: 12A · 6A · 12P · 6P.
          Row(
            children: [
              for (final (flex, label) in [
                (6, '12 AM'),
                (6, '6 AM'),
                (6, '12 PM'),
                (6, '6 PM'),
              ])
                Expanded(
                  flex: flex,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: FoxColors.textDisabled,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Per-app verdict breakdown: one horizontal stacked bar per platform,
/// segments in verdict colors (good/ok/bad), bar length proportional to the
/// busiest app so cross-app volume compares at a glance. Counts label each
/// row's end; identity comes from badge + name, never color alone.
class _AppVerdictChart extends StatelessWidget {
  const _AppVerdictChart({required this.offers});
  final List<OfferSummary> offers;

  @override
  Widget build(BuildContext context) {
    // (good, ok, bad) per platform, apps with 0 offers skipped.
    final rows = <(GigPlatform, int, int, int)>[];
    var maxTotal = 0;
    for (final p in GigPlatform.values) {
      var g = 0, k = 0, b = 0;
      for (final o in offers) {
        if (o.platform != p) continue;
        switch (o.verdict) {
          case Verdict.good:
            g++;
          case Verdict.ok:
            k++;
          case Verdict.bad:
            b++;
          case Verdict.unknown:
            break;
        }
      }
      final total = g + k + b;
      if (total == 0) continue;
      rows.add((p, g, k, b));
      if (total > maxTotal) maxTotal = total;
    }
    if (rows.length < 2) {
      // 1 app → hourly chart already tells the story
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Gap.md + Gap.xs,
        Gap.md,
        Gap.md + Gap.xs,
        Gap.md,
      ),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BY APP', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              // Tiny legend: dot + word per verdict.
              for (final (c, l) in [
                (VerdictColors.goodFill, 'good'),
                (VerdictColors.okFill, 'ok'),
                (VerdictColors.badFill, 'bad'),
              ]) ...[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: Gap.sm),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const SizedBox(width: 3),
                Text(
                  l,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.sm + Gap.xs),
          for (final (p, g, k, b) in rows) ...[
            _appRow(context, p, g, k, b, maxTotal),
            if ((p, g, k, b) != rows.last) const SizedBox(height: Gap.sm),
          ],
        ],
      ),
    );
  }

  Widget _appRow(
    BuildContext context,
    GigPlatform p,
    int good,
    int ok,
    int bad,
    int maxTotal,
  ) {
    final total = good + ok + bad;
    return Row(
      children: [
        // Fixed label column keeps the bars' baselines aligned.
        SizedBox(
          width: 76,
          child: Row(
            children: [
              PlatformBadge(platform: p, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  p.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: total / maxTotal,
            // Matches the Home segment bar: 10dp lozenges rather than one 14dp
            // slab of saturated color (device 2026-07-25: "too thick").
            child: SizedBox(
              height: 11,
              child: Builder(
                builder: (context) {
                  final segs = [
                    (good, VerdictColors.goodFill),
                    (ok, VerdictColors.okFill),
                    (bad, VerdictColors.badFill),
                  ].where((s) => s.$1 > 0).toList();
                  return Row(
                    children: [
                      for (final (i, (count, color)) in segs.indexed)
                        Expanded(
                          flex: count,
                          child: Container(
                            margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Radii.pill),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(color, Colors.white, 0.18)!,
                                  color,
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: Gap.sm),
        SizedBox(
          width: 24,
          child: Text(
            '$total',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: FoxColors.cream,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferRow extends ConsumerWidget {
  const _OfferRow({required this.offer});
  final OfferSummary offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final outcome = OutcomeStyle.of(offer.outcome);
    // Locale-aware (12h markets see "6:48 PM", not hardcoded 24h).
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(offer.seenAt),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.cardSm),
      onTap: () => showOfferDetail(context, offer),
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.sm),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
        decoration: BoxDecoration(
          color: FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(color: FoxColors.borderSoft),
          boxShadow: Shadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: outcome.color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: outcome.color.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PlatformBadge(platform: offer.platform, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        offer.platform.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FoxColors.textPrimary,
                        ),
                      ),
                      if (offer.category != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            offer.category!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: FoxColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _VerdictTag(verdict: offer.verdict),
                      _OutcomeMenu(offer: offer, style: outcome),
                      if (offer.isQueued)
                        Text(
                          'QUEUED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: FoxColors.textSecondary,
                          ),
                        ),
                      if (offer.bonus > 0)
                        Text(
                          '+${settings.currency.prefix}${offer.bonus.toStringAsFixed(2)} bonus',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: VerdictColors.good,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${settings.distanceUnit.distanceFromKm(offer.totalKm).toStringAsFixed(1)} ${settings.distanceUnit.shortLabel}  ',
                        ),
                        TextSpan(
                          text:
                              '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(offer.pricePerKm).toStringAsFixed(2)}/${settings.distanceUnit.shortLabel}',
                          style: TextStyle(
                            color: FoxColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      style: TextStyle(
                        fontSize: 12,
                        color: FoxColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  offer.payout == offer.payout.roundToDouble()
                      ? '${settings.currency.prefix}${offer.payout.toStringAsFixed(0)}'
                      : '${settings.currency.prefix}${offer.payout.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: FoxFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeMenu extends ConsumerWidget {
  const _OutcomeMenu({required this.offer, required this.style});

  final OfferSummary offer;
  final OutcomeStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      key: ValueKey('offer_outcome_${offer.seenAt.microsecondsSinceEpoch}'),
      button: true,
      label: '${style.label}. Change outcome',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () async {
          HapticFeedback.selectionClick();
          final value = await showModalBottomSheet<OfferOutcome>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _OutcomeSheet(selected: offer.outcome),
          );
          if (value != null) {
            ref.read(offerLogProvider.notifier).setOutcome(offer, value);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: style.color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 12, color: style.color),
              const SizedBox(width: 4),
              Text(
                style.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: style.color,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.edit_rounded, size: 11, color: style.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictTag extends StatelessWidget {
  const _VerdictTag({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeSheet extends StatelessWidget {
  const _OutcomeSheet({required this.selected});
  final OfferOutcome selected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Offer outcome', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.sm),
          for (final value in const [
            OfferOutcome.taken,
            OfferOutcome.missed,
            OfferOutcome.cancelled,
            OfferOutcome.completed,
            OfferOutcome.unknown,
          ])
            ListTile(
              minTileHeight: 52,
              leading: Icon(
                OutcomeStyle.of(value).icon,
                color: OutcomeStyle.of(value).color,
              ),
              title: Text(OutcomeStyle.of(value).label),
              trailing: value == selected
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    ),
  );
}

/// Empty state. When offers exist but filters hide them, say so and offer a
/// one-tap reset (spec M6 §5.1) — "0 results" with 22 offers on disk reads
/// as data loss otherwise.
class _Empty extends StatelessWidget {
  const _Empty({required this.hiddenCount, this.onShowAll});

  final int hiddenCount;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final filtered = hiddenCount > 0 && onShowAll != null;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: 40),
      child: Column(
        children: [
          if (filtered) ...[
            Icon(
              Icons.filter_alt_off_outlined,
              size: 36,
              color: FoxColors.textDisabled,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              '$hiddenCount offers outside these filters',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: FoxColors.textDisabled),
            ),
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: onShowAll,
              style: TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              child: const Text(
                'Show all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ] else ...[
            Text(
              'No offers yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FoxColors.textPrimary,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Go live and let the fox hunt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: FoxColors.textSecondary,
              ),
            ),
            const SizedBox(height: Gap.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    'assets/history/hunt.webp',
                    fit: BoxFit.cover,
                    semanticLabel:
                        'Fox driver waiting beside a car near a mountain lake',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shift-summary rollup over the CURRENTLY FILTERED offers, so the numbers
/// always mean "for the range/apps you picked". Count-only + two derived
/// figures — no graphs (MVP).
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.stats});

  final OfferStats stats;

  /// `17` → "5 PM" (hour-of-day label for the busiest-hour stat).
  static String _hourLabel(int h) {
    final ampm = h < 12 ? 'AM' : 'PM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display $ampm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats;
    final settings = ref.watch(settingsProvider);
    return Container(
      key: const ValueKey('history-summary'),
      padding: const EdgeInsets.all(Gap.md + Gap.xs),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: FoxColors.brandFox),
              const SizedBox(width: Gap.sm),
              Text('SUMMARY', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'OFFERS',
                  value: '${s.total}',
                  emphasis: true,
                  // Verdict-colored counts instead of the cryptic "2·7·2".
                  subSpan: TextSpan(
                    children: [
                      TextSpan(
                        text: '${s.good} good',
                        style: TextStyle(color: VerdictColors.good),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: '${s.ok} ok',
                        style: TextStyle(color: VerdictColors.ok),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: '${s.bad} bad',
                        style: TextStyle(color: VerdictColors.bad),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _Stat(
                  label: 'GOOD AVG',
                  value: s.goodAvgPerKm > 0
                      ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(s.goodAvgPerKm).toStringAsFixed(2)}'
                      : '—',
                  sub: 'per ${settings.distanceUnit.shortLabel}',
                  valueColor: FoxColors.textPrimary,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Gap.md),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'BEST RATE',
                  value: s.best != null && s.best!.pricePerKm > 0
                      ? '${settings.currency.prefix}${settings.distanceUnit.rateFromPerKm(s.best!.pricePerKm).toStringAsFixed(2)}'
                      : '—',
                  sub: s.best != null
                      ? '${s.best!.platform.label} · per ${settings.distanceUnit.shortLabel}'
                      : '',
                  valueColor: FoxColors.textPrimary,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _Stat(
                  label: 'BUSIEST HOUR',
                  value: s.busiestHour != null
                      ? _hourLabel(s.busiestHour!)
                      : '—',
                  sub: '${s.accepted} of ${s.total} accepted',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.sub,
    this.subSpan,
    this.valueColor,
    this.emphasis = false,
  }) : assert(sub != null || subSpan != null);

  final String label;
  final String value;
  final String? sub;
  final TextSpan? subSpan;
  final Color? valueColor;
  final bool emphasis;

  static bool _isInt(String s) => int.tryParse(s) != null;
  static TextStyle get _valueStyle => TextStyle(
    fontFamily: FoxFonts.display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: FoxColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: FoxColors.textDisabled,
          ),
        ),
        const SizedBox(height: Gap.xs),
        SizedBox(
          height: emphasis ? 40 : 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _isInt(value)
                ? TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: int.parse(value)),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : Motion.count,
                    curve: Motion.curve,
                    builder: (context, v, _) => Text(
                      '$v',
                      style: _valueStyle.copyWith(
                        color: valueColor,
                        fontSize: emphasis ? 36 : 17,
                        height: emphasis ? 1 : null,
                      ),
                    ),
                  )
                : Text(
                    value,
                    maxLines: 1,
                    style: _valueStyle.copyWith(
                      color: valueColor,
                      fontSize: emphasis ? 36 : 17,
                      height: emphasis ? 1 : null,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            subSpan ?? TextSpan(text: sub),
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              color: FoxColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
