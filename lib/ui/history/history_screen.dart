import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../../domain/fox_settings.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../../services/session_log.dart';
import '../../parser/parser_registry.dart';
import '../settings/settings_controller.dart';
import '../theme/platform_badge.dart';
import '../theme/outcome_style.dart';
import '../theme/section_label.dart';
import '../theme/step_button.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';
import 'offer_detail_sheet.dart';
import 'history_intent.dart';

/// History (references/foxyco_history.html).
///
/// Time range + app, verdict and trip-status filters + a minimum-fare
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
  needsReview,
}

String _outcomeLabel(HistoryOutcomeFilter value) => switch (value) {
  HistoryOutcomeFilter.all => 'All outcomes',
  HistoryOutcomeFilter.accepted => 'Accepted',
  HistoryOutcomeFilter.declined => 'Not taken',
  HistoryOutcomeFilter.cancelled => 'Cancelled',
  HistoryOutcomeFilter.completed => 'Completed',
  HistoryOutcomeFilter.unknown => 'Unknown',
  HistoryOutcomeFilter.needsReview => 'Needs review',
};

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _bottomNavClearance = 112.0;
  ScrollController? _scrollController;
  bool _showBackToTop = false;
  HistoryRange _range = HistoryRange.today;
  final Set<GigPlatform?> _apps = {null}; // null == "All"
  final Set<Verdict?> _verdicts = {null}; // null == "All"
  HistoryOutcomeFilter _outcome = HistoryOutcomeFilter.all;
  bool _topOnly = false;
  int _minFare = 20;

  @override
  void initState() {
    super.initState();
    ref.listenManual<HistoryIntent?>(pendingHistoryIntentProvider, (_, intent) {
      if (intent != HistoryIntent.needsReview || !mounted) return;
      setState(() {
        _range = HistoryRange.all;
        _outcome = HistoryOutcomeFilter.needsReview;
        _apps
          ..clear()
          ..add(null);
        _verdicts
          ..clear()
          ..add(null);
        _topOnly = false;
      });
      ref.read(pendingHistoryIntentProvider.notifier).clear();
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PrimaryScrollController.maybeOf(context);
    if (next == _scrollController) return;
    _scrollController?.removeListener(_handleScroll);
    _scrollController = next;
    _scrollController?.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final threshold = MediaQuery.sizeOf(context).height * 1.1;
    final next = controller.offset > threshold;
    if (next == _showBackToTop || !mounted) return;
    setState(() => _showBackToTop = next);
  }

  void _backToTop() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(0, duration: Motion.morph, curve: Motion.curve);
  }

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
      HistoryOutcomeFilter.accepted =>
        o.outcome == OfferOutcome.taken || o.outcome == OfferOutcome.completed,
      HistoryOutcomeFilter.declined => o.outcome == OfferOutcome.missed,
      HistoryOutcomeFilter.cancelled => o.outcome == OfferOutcome.cancelled,
      HistoryOutcomeFilter.completed => o.outcome == OfferOutcome.completed,
      HistoryOutcomeFilter.unknown => o.outcome == OfferOutcome.unknown,
      HistoryOutcomeFilter.needsReview =>
        o.outcome == OfferOutcome.unknown ||
            ((o.outcome == OfferOutcome.taken ||
                    o.outcome == OfferOutcome.completed) &&
                o.finalPayout == null),
    };
    if (!outcomeMatches) return false;
    // Top-only is a FARE floor, nothing more. It used to also require
    // verdict == GOOD, which read as "filter broken": raise the fare and a
    // $22 OK offer silently vanished (device 2026-07-19). Verdict now has its
    // own chips above.
    if (_topOnly && o.effectivePayout < _minFare) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(offerLogProvider);
    final availableApps = ParserRegistry.supportedPlatforms;
    final filtered = all.where(_passes).toList()
      ..sort(
        (a, b) => _topOnly
            ? b.effectivePricePerKm.compareTo(a.effectivePricePerKm)
            : b.seenAt.compareTo(a.seenAt),
      );
    final stats = OfferStats.from(filtered);

    return Stack(
      children: [
        ListView(
          // 100 clears the floating nav; add the gesture-bar inset like Home does
          // (fixed 100 clipped the last card on gesture-nav phones).
          padding: EdgeInsets.fromLTRB(
            Gap.md,
            Gap.sm,
            Gap.md,
            _bottomNavClearance + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
              expanded: false,
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
              onToggle: () => _showFilters(availableApps),
            ),
            const SizedBox(height: Gap.md),
            if (filtered.isEmpty)
              _Empty(
                hiddenCount: all.length,
                onShowAll: all.isEmpty ? null : () => setState(_resetFilters),
              )
            else ...[
              const _SummaryHeading(),
              const SizedBox(height: Gap.sm),
              _StatsCard(stats: stats),
              const SizedBox(height: Gap.sm),
              _HourlyChart(offers: filtered),
              const SizedBox(height: Gap.sm),
              _AppVerdictChart(offers: filtered),
              const SizedBox(height: Gap.lg),
              ..._grouped(filtered),
            ],
          ],
        ),
        Positioned(
          right: Gap.md,
          bottom: MediaQuery.of(context).padding.bottom + 76,
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.curve,
            switchOutCurve: Motion.curve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _showBackToTop
                ? Semantics(
                    key: const ValueKey('history_back_to_top_semantics'),
                    button: true,
                    label: 'Back to top',
                    child: Material(
                      color: FoxColors.bgSurface,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        key: const ValueKey('history_back_to_top'),
                        tooltip: 'Back to top',
                        onPressed: _backToTop,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        color: FoxColors.brandFox,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('history_back_to_top_hidden'),
                    width: 48,
                    height: 48,
                  ),
          ),
        ),
      ],
    );
  }

  void _toggleApp(GigPlatform? app) {
    setState(() => _toggleIn(_apps, app));
  }

  void _toggleVerdict(Verdict? v) {
    setState(() => _toggleIn(_verdicts, v));
  }

  Future<void> _showFilters(List<GigPlatform> availableApps) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FoxColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.hero)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) {
          void update(VoidCallback change) {
            setState(change);
            refreshSheet(() {});
          }

          return FractionallySizedBox(
            heightFactor: 0.92,
            child: Column(
              children: [
                const SizedBox(height: Gap.sm),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: FoxColors.border,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      Gap.md,
                      Gap.sm,
                      Gap.md,
                      Gap.md + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: _FiltersCard(
                      expanded: true,
                      range: _range,
                      apps: _apps,
                      verdicts: _verdicts,
                      availableApps: availableApps,
                      outcome: _outcome,
                      topOnly: _topOnly,
                      minFare: _minFare,
                      matchCount: ref
                          .read(offerLogProvider)
                          .where(_passes)
                          .length,
                      onRange: (range) => update(() {
                        _range = range;
                        if (range == HistoryRange.all) _resetFilters();
                      }),
                      onApp: (app) => update(() => _toggleIn(_apps, app)),
                      onVerdict: (verdict) =>
                          update(() => _toggleIn(_verdicts, verdict)),
                      onOutcome: (outcome) => update(() => _outcome = outcome),
                      onTopToggle: () => update(() => _topOnly = !_topOnly),
                      onFare: (delta) => update(
                        () => _minFare = (_minFare + delta).clamp(0, 100),
                      ),
                      onReset: () => update(_resetFilters),
                      onToggle: () => Navigator.pop(sheetContext),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    Gap.md,
                    Gap.sm,
                    Gap.md,
                    Gap.sm + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: FoxColors.bgSurface,
                    border: Border(
                      top: BorderSide(color: FoxColors.borderSoft),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => update(_resetFilters),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const ValueKey('history-filter-done'),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            'Show ${ref.read(offerLogProvider).where(_passes).length} offers',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
      padding: EdgeInsets.all(expanded ? Gap.sm : Gap.md),
      decoration: BoxDecoration(
        color: expanded ? Colors.transparent : FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: expanded ? null : Border.all(color: FoxColors.borderSoft),
        boxShadow: expanded ? null : Shadows.soft,
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
                      padding: EdgeInsets.all(
                        expanded ? Gap.sm + Gap.xs : Gap.sm,
                      ),
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
                            expanded
                                ? 'Filter offers'
                                : _activeCount == 0
                                ? 'Filters'
                                : 'Filters · $_activeCount active',
                            style: TextStyle(
                              fontSize: expanded ? 20 : 15,
                              fontWeight: FontWeight.w700,
                              color: FoxColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expanded ? 'Refine your history results' : _summary,
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: FoxColors.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: FoxColors.borderSoft),
                        boxShadow: expanded ? Shadows.soft : null,
                      ),
                      child: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: Motion.base,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: FoxColors.textSecondary,
                        ),
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
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    const Expanded(child: _FilterHeading('1. Date range')),
                    TextButton(
                      onPressed: _activeCount == 0 ? null : onReset,
                      child: const Text('Reset filters'),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                _RangeControl(value: range, onChanged: onRange),
                const SizedBox(height: Gap.sm),
                _FilterGroup(
                  label: '2. Platforms',
                  child: _AppChips(
                    selected: apps,
                    availableApps: availableApps,
                    onToggle: onApp,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                _FilterGroup(
                  label: '3. Verdict',
                  child: _VerdictChips(selected: verdicts, onToggle: onVerdict),
                ),
                const SizedBox(height: Gap.sm),
                _FilterGroup(
                  label: '4. Outcome',
                  child: _OutcomeChips(selected: outcome, onChanged: onOutcome),
                ),
                const SizedBox(height: Gap.sm),
                _FilterGroup(
                  label: '5. Minimum fare',
                  child: _TopFilter(
                    on: topOnly,
                    minFare: minFare,
                    matchCount: matchCount,
                    onToggle: onTopToggle,
                    onFare: onFare,
                  ),
                ),
                const SizedBox(height: Gap.md),
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
        _FilterHeading(label),
        const SizedBox(height: Gap.xs),
        child,
      ],
    );
  }
}

class _FilterHeading extends StatelessWidget {
  const _FilterHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: FoxColors.textPrimary,
    ),
  );
}

class _ThreeColumnGrid extends StatelessWidget {
  const _ThreeColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: Gap.sm,
    crossAxisSpacing: Gap.sm,
    mainAxisExtent: 48,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );
}

class _OutcomeChips extends StatelessWidget {
  const _OutcomeChips({required this.selected, required this.onChanged});

  final HistoryOutcomeFilter selected;
  final ValueChanged<HistoryOutcomeFilter> onChanged;

  @override
  Widget build(BuildContext context) => _ThreeColumnGrid(
    children: [
      for (final value in HistoryOutcomeFilter.values.skip(1)) _chip(value),
    ],
  );

  Widget _chip(HistoryOutcomeFilter value) {
    final active = selected == value;
    final style = switch (value) {
      HistoryOutcomeFilter.accepted ||
      HistoryOutcomeFilter.completed => VerdictColors.good,
      HistoryOutcomeFilter.cancelled => VerdictColors.bad,
      _ => VerdictColors.unknown,
    };
    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        key: ValueKey('history-outcome-${value.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(active ? HistoryOutcomeFilter.all : value);
        },
        child: AnimatedContainer(
          duration: Motion.base,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? style.withValues(alpha: 0.10) : FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: active
                  ? style.withValues(alpha: 0.65)
                  : FoxColors.borderSoft,
            ),
            boxShadow: active ? null : Shadows.soft,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value == HistoryOutcomeFilter.cancelled
                      ? Icons.cancel_outlined
                      : value == HistoryOutcomeFilter.unknown
                      ? Icons.help_outline_rounded
                      : value == HistoryOutcomeFilter.declined
                      ? Icons.remove_circle_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: active ? style : FoxColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _outcomeLabel(value),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? style : FoxColors.textSecondary,
                  ),
                ),
              ],
            ),
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
    return _ThreeColumnGrid(
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app != null) ...[
                PlatformBadge(platform: app, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: FoxColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Verdict grouping chips (good / ok / bad), same multi-select + "All"
/// behavior as [_AppChips]. Icon + word, never color alone (colorblind-safe).
class _VerdictChips extends StatelessWidget {
  const _VerdictChips({required this.selected, required this.onToggle});
  final Set<Verdict?> selected;
  final ValueChanged<Verdict?> onToggle;

  @override
  Widget build(BuildContext context) {
    return _ThreeColumnGrid(
      children: [
        for (final v in const [Verdict.good, Verdict.ok, Verdict.bad]) _chip(v),
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (style != null) ...[
                Icon(
                  style.icon,
                  size: 12,
                  color: active ? FoxColors.brandFox : style.color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                style!.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: FoxColors.textPrimary,
                ),
              ),
            ],
          ),
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
                      'Filter by minimum fare',
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
      label: 'Filter by minimum fare',
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
      key: const Key('history_by_hour'),
      padding: const EdgeInsets.fromLTRB(
        Gap.md + Gap.xs,
        Gap.md,
        Gap.md + Gap.xs,
        Gap.sm + Gap.xs,
      ),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
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
      key: const Key('history_by_app'),
      padding: const EdgeInsets.fromLTRB(
        Gap.md + Gap.xs,
        Gap.md,
        Gap.md + Gap.xs,
        Gap.md,
      ),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
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
          width: Gap.xxl,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$total',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: FoxColors.cream,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
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
    final payout = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            offer.effectivePayout == offer.effectivePayout.roundToDouble()
                ? '${settings.currency.prefix}${offer.effectivePayout.toStringAsFixed(0)}'
                : '${settings.currency.prefix}${offer.effectivePayout.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: FoxColors.brandText,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (offer.finalPayout != null)
          Text(
            'from ${settings.currency.prefix}${offer.payout.toStringAsFixed(2)}',
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: FoxColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
    return InkWell(
      key: ValueKey('history-offer-${offer.seenAt.microsecondsSinceEpoch}'),
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
                      Expanded(
                        child: Row(
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
                      ),
                      const SizedBox(width: Gap.sm),
                      SizedBox(width: 112, child: payout),
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
                    ],
                  ),
                  if (offer.bonus > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${settings.currency.prefix}${offer.bonus.toStringAsFixed(2)} bonus',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: VerdictColors.good,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (offer.tip > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${settings.currency.prefix}${offer.tip.toStringAsFixed(2)} tip',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: VerdictColors.good,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (offer.tollReimbursement > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${settings.currency.prefix}${offer.tollReimbursement.toStringAsFixed(2)} toll reimbursement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.brandFox,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: Gap.sm),
                  Divider(height: 1, color: FoxColors.borderSoft),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _OfferMetric(
                          icon: Icons.location_on_rounded,
                          value:
                              '${settings.distanceUnit.distanceFromKm(offer.totalKm).toStringAsFixed(1)} ${settings.distanceUnit.shortLabel}',
                        ),
                      ),
                      const SizedBox(width: Gap.xs),
                      SizedBox(
                        height: 20,
                        child: VerticalDivider(color: FoxColors.border),
                      ),
                      const SizedBox(width: Gap.xs),
                      Expanded(
                        child: _OfferMetric(
                          icon: Icons.speed_rounded,
                          value:
                              '${settings.currency.symbol}${settings.distanceUnit.rateFromPerKm(offer.effectivePricePerKm).toStringAsFixed(2)}/${settings.distanceUnit.shortLabel}',
                          emphasized: true,
                        ),
                      ),
                      const SizedBox(width: Gap.xs),
                      SizedBox(
                        height: 20,
                        child: VerticalDivider(color: FoxColors.border),
                      ),
                      const SizedBox(width: Gap.xs),
                      Expanded(
                        child: _OfferMetric(
                          icon: Icons.schedule_rounded,
                          value: time,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferMetric extends StatelessWidget {
  const _OfferMetric({
    required this.icon,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: FoxColors.textSecondary),
      const SizedBox(width: Gap.xs),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: emphasized
                  ? FoxColors.textPrimary
                  : FoxColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    ],
  );
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
            final changed = ref
                .read(offerLogProvider.notifier)
                .setOutcome(offer, value);
            if (changed) {
              await ref
                  .read(sessionLogProvider.notifier)
                  .refreshForOffer(offer, ref.read(offerLogProvider));
            }
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
                maxLines: 1,
                softWrap: false,
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

class _VerdictSummaryRow extends StatelessWidget {
  const _VerdictSummaryRow({required this.stats});

  final OfferStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _VerdictSummaryChip(
        count: stats.good,
        verdict: Verdict.good,
        icon: Icons.check_circle_outline_rounded,
      ),
      const SizedBox(width: Gap.sm),
      _VerdictSummaryChip(
        count: stats.ok,
        verdict: Verdict.ok,
        icon: Icons.radio_button_checked_rounded,
      ),
      const SizedBox(width: Gap.sm),
      _VerdictSummaryChip(
        count: stats.bad,
        verdict: Verdict.bad,
        icon: Icons.cancel_outlined,
      ),
    ],
  );
}

class _VerdictSummaryChip extends StatelessWidget {
  const _VerdictSummaryChip({
    required this.count,
    required this.verdict,
    required this.icon,
  });

  final int count;
  final Verdict verdict;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(verdict);
    return Expanded(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(Radii.cardSm),
          border: Border.all(color: style.color.withValues(alpha: 0.42)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: style.color),
              const SizedBox(width: 6),
              Text(
                '$count',
                key: ValueKey('history-summary-${verdict.name}'),
                style: TextStyle(
                  fontFamily: FoxFonts.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: style.color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryPerformance extends StatefulWidget {
  const _HistoryPerformance({required this.stats, required this.settings});

  final OfferStats stats;
  final FoxSettings settings;

  @override
  State<_HistoryPerformance> createState() => _HistoryPerformanceState();
}

class _HistoryPerformanceState extends State<_HistoryPerformance> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final settings = widget.settings;
    final earnings = stats.acceptedEarnings > 0
        ? '${settings.currency.symbol}${stats.acceptedEarnings.toStringAsFixed(2)}'
        : '—';
    final hourly = stats.acceptedMinutes > 0
        ? '${settings.currency.symbol}${(stats.acceptedPerformanceEarnings / stats.acceptedMinutes * 60).toStringAsFixed(2)}'
        : '—';
    final acceptedKm = stats.acceptedKm > 0
        ? settings.distanceUnit
              .distanceFromKm(stats.acceptedKm)
              .toStringAsFixed(1)
        : '—';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final expandedHeight = 260.0 + (textScale > 1 ? (textScale - 1) * 80 : 0);
    final light = Theme.of(context).brightness == Brightness.light;

    return Semantics(
      button: true,
      expanded: _expanded,
      label: 'History performance',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: GestureDetector(
          key: const Key('history-performance-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            key: const ValueKey('history-performance-card'),
            height: _expanded ? expandedHeight : 72,
            decoration: BoxDecoration(
              color: light ? const Color(0xFFFFF8EE) : const Color(0xFF090D1C),
              image: DecorationImage(
                image: AssetImage(
                  light
                      ? 'assets/history/city_light.webp'
                      : 'assets/history/city_dark.webp',
                ),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                opacity: light ? 0.72 : 1,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: FoxColors.textPrimary.withValues(
                  alpha: light ? 0.10 : 0.18,
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: light
                          ? const [
                              Color(0xEFFFF9F0),
                              Color(0xC8FFF8EE),
                              Color(0x40FFF4E8),
                            ]
                          : const [
                              Color(0xE6071020),
                              Color(0xB8071022),
                              Color(0x4024133A),
                            ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 330;
                    return Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: _expanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                size: 18,
                                color: light
                                    ? FoxColors.brandFox
                                    : const Color(0xFF79DC91),
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Text(
                                  _expanded
                                      ? 'History performance'
                                      : stats.accepted == 0
                                      ? 'No accepted offers'
                                      : '$earnings   |   $hourly/hr trip',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: _expanded
                                        ? null
                                        : FoxFonts.display,
                                    fontSize: _expanded ? 13 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: FoxColors.textPrimary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                _expanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: FoxColors.textSecondary,
                              ),
                            ],
                          ),
                          if (_expanded) ...[
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _HeroValue(
                                    label: 'Estimated earnings',
                                    value: earnings,
                                    fontSize: compact ? 25 : 29,
                                    valueKey: const ValueKey(
                                      'history-performance-earnings',
                                    ),
                                    color: light
                                        ? FoxColors.brandFoxDeep
                                        : FoxColors.brandFox,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 62,
                                  color: FoxColors.border,
                                ),
                                Expanded(
                                  flex: 9,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: Gap.md,
                                    ),
                                    child: _HeroValue(
                                      label: 'Trip rate',
                                      value: hourly,
                                      sub: 'Per accepted trip hour',
                                      fontSize: compact ? 22 : 26,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              height: 62,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.sm,
                              ),
                              decoration: BoxDecoration(
                                color: light
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : const Color(0xCC0B1122),
                                borderRadius: BorderRadius.circular(
                                  Radii.cardSm,
                                ),
                                border: Border.all(color: FoxColors.border),
                              ),
                              child: Row(
                                children: [
                                  _HeroStat(
                                    value: '${stats.total}',
                                    label: 'Offers',
                                    valueKey: const ValueKey(
                                      'history-summary-total',
                                    ),
                                  ),
                                  const _GlassDivider(),
                                  _HeroStat(
                                    value: '${stats.accepted}',
                                    label: 'Accepted',
                                  ),
                                  const _GlassDivider(),
                                  _HeroStat(
                                    value: acceptedKm,
                                    label:
                                        'Accepted ${settings.distanceUnit.shortLabel}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.fontSize,
    this.sub,
    this.color,
    this.valueKey,
  });

  final String label;
  final String value;
  final String? sub;
  final double fontSize;
  final Color? color;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FoxColors.textSecondary,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        key: valueKey,
        style: TextStyle(
          fontFamily: FoxFonts.display,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color ?? FoxColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(
          sub!,
          style: TextStyle(fontSize: 10.5, color: FoxColors.textSecondary),
        ),
      ],
    ],
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, this.valueKey});
  final String value;
  final String label;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            key: valueKey,
            style: TextStyle(
              fontFamily: FoxFonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: FoxColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(fontSize: 9.5, color: FoxColors.textSecondary),
        ),
      ],
    ),
  );
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: FoxColors.border);
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
              color: FoxColors.textSecondary,
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
              'Go live to start recording offers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: FoxColors.textSecondary,
              ),
            ),
          ],
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
      ),
    );
  }
}

/// Shift-summary rollup over the CURRENTLY FILTERED offers, so the numbers
/// always mean "for the range/apps you picked". Count-only + two derived
/// figures — no graphs (MVP).
class _SummaryHeading extends StatelessWidget {
  const _SummaryHeading();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.insights_rounded, size: 16, color: FoxColors.brandFox),
      const SizedBox(width: Gap.sm),
      Text(
        'SUMMARY',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

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
    final best = s.best;
    final bestColor = switch (best?.verdict) {
      Verdict.good => VerdictColors.good,
      Verdict.ok => VerdictColors.ok,
      Verdict.bad => VerdictColors.bad,
      _ => FoxColors.textSecondary,
    };
    return Column(
      key: const ValueKey('history-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VerdictSummaryRow(stats: s),
        const SizedBox(height: Gap.sm),
        _HistoryPerformance(stats: s, settings: settings),
        const SizedBox(height: Gap.sm),
        Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(color: FoxColors.borderSoft),
            boxShadow: Shadows.soft,
          ),
          child: Row(
            children: [
              _CompactStat(
                icon: Icons.trending_up_rounded,
                label: 'Good avg',
                value: s.goodAvgPerKm > 0
                    ? '${settings.currency.symbol}${settings.distanceUnit.rateFromPerKm(s.goodAvgPerKm).toStringAsFixed(2)}'
                    : '—',
                color: s.goodAvgPerKm > 0
                    ? VerdictColors.good
                    : FoxColors.textSecondary,
              ),
              const _StatDivider(),
              _CompactStat(
                icon: Icons.star_outline_rounded,
                label: 'Best rate',
                value: best != null && best.effectivePricePerKm > 0
                    ? '${settings.currency.symbol}${settings.distanceUnit.rateFromPerKm(best.effectivePricePerKm).toStringAsFixed(2)}'
                    : '—',
                color: bestColor,
              ),
              const _StatDivider(),
              _CompactStat(
                icon: Icons.schedule_rounded,
                label: 'Busiest hour',
                value: s.busiestHour != null ? _hourLabel(s.busiestHour!) : '—',
                color: FoxColors.brandFox,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: FoxColors.border);
}
