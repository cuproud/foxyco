import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_stats.dart';
import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../theme/platform_badge.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// History (references/foxyco_history.html).
///
/// Time range + per-app chips + a "top offers only" filter over the live
/// offer log ([offerLogProvider]) — every scored offer FoxyCo has seen.
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

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryRange _range = HistoryRange.today;
  final Set<GigPlatform?> _apps = {null}; // null == "All"
  final Set<Verdict?> _verdicts = {null}; // null == "All"
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
        if (d > 7) return false;
      case HistoryRange.month:
        if (d > 30) return false;
      case HistoryRange.all:
        break;
    }
    if (!_apps.contains(null) && !_apps.contains(o.platform)) return false;
    if (!_verdicts.contains(null) && !_verdicts.contains(o.verdict)) {
      return false;
    }
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
    final filtered = all.where(_passes).toList()
      ..sort((a, b) => _topOnly
          ? b.pricePerKm.compareTo(a.pricePerKm)
          : b.seenAt.compareTo(a.seenAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 100),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('History', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            Text(
              HistoryScreen.headerLabel(filtered.length, _range),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FoxColors.textDisabled,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _RangeControl(
          value: _range,
          onChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: Gap.sm + Gap.xs),
        _AppChips(
          selected: _apps,
          onToggle: _toggleApp,
        ),
        const SizedBox(height: Gap.sm),
        _VerdictChips(
          selected: _verdicts,
          onToggle: _toggleVerdict,
        ),
        const SizedBox(height: Gap.md),
        _TopCard(
          on: _topOnly,
          minFare: _minFare,
          matchCount: filtered.length,
          onToggle: () => setState(() => _topOnly = !_topOnly),
          onFare: (d) => setState(
              () => _minFare = (_minFare + d).clamp(0, 100)),
        ),
        const SizedBox(height: Gap.lg),
        if (filtered.isEmpty)
          _Empty(
            hiddenCount: all.length,
            onShowAll: all.isEmpty
                ? null
                : () => setState(() {
                      _range = HistoryRange.all;
                      _apps
                        ..clear()
                        ..add(null);
                      _verdicts
                        ..clear()
                        ..add(null);
                      _topOnly = false;
                    }),
          )
        else ...[
          _StatsCard(stats: OfferStats.from(filtered)),
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
        out.add(Padding(
          padding: EdgeInsets.only(top: lastLabel == null ? 0 : Gap.md, bottom: Gap.sm),
          child: _DateHeader(label),
        ));
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
      key: ValueKey('${o.seenAt.millisecondsSinceEpoch}-$_range-$_topOnly'),
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
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
      height: 40,
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.soft,
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(builder: (context, c) {
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
                  color: FoxColors.bgSurface2,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            Row(
              children: [
                for (final r in items)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(r),
                      child: Center(
                        child: Text(
                          _labels[r]!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: r == value
                                ? FoxColors.cream
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
      }),
    );
  }
}

class _AppChips extends StatelessWidget {
  const _AppChips({required this.selected, required this.onToggle});
  final Set<GigPlatform?> selected;
  final ValueChanged<GigPlatform?> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        _chip(null, 'All'),
        for (final p in const [
          GigPlatform.uber,
          GigPlatform.lyft,
          GigPlatform.hopp,
        ])
          _chip(p, p.label),
      ],
    );
  }

  Widget _chip(GigPlatform? app, String label) {
    final active = selected.contains(app);
    return GestureDetector(
      onTap: () => onToggle(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? FoxColors.bgSurface2 : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
              color: active ? FoxColors.border : FoxColors.borderSoft),
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
                color: active ? FoxColors.cream : FoxColors.textSecondary,
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
  const _VerdictChips({required this.selected, required this.onToggle});
  final Set<Verdict?> selected;
  final ValueChanged<Verdict?> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        _chip(null),
        for (final v in const [Verdict.good, Verdict.ok, Verdict.bad])
          _chip(v),
      ],
    );
  }

  Widget _chip(Verdict? v) {
    final active = selected.contains(v);
    final style = v == null ? null : VerdictStyle.of(v);
    return GestureDetector(
      onTap: () => onToggle(v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? FoxColors.bgSurface2 : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
              color: active ? FoxColors.border : FoxColors.borderSoft),
          boxShadow: active ? null : Shadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (style != null) ...[
              Icon(style.icon,
                  size: 12, color: active ? style.color : FoxColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              style?.label ?? 'All',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? FoxColors.cream : FoxColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark "top offers only" card with a switch + fare stepper.
class _TopCard extends StatelessWidget {
  const _TopCard({
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
      padding: const EdgeInsets.all(Gap.md + Gap.xs),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.card + 2),
        boxShadow: Shadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFFB25C), size: 20), // warm streak-flame accent — one-off
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top offers only',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      on ? 'Offers over \$$minFare' : 'Best \$/km, all fares',
                      style: TextStyle(
                        fontSize: 12,
                        color: FoxColors.cream.withValues(alpha: 0.55),
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
            crossFadeState:
                on ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Row(
                children: [
                  Text(
                    'Minimum fare',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: FoxColors.cream.withValues(alpha: 0.65),
                    ),
                  ),
                  const Spacer(),
                  _StepBtn('–', () => onFare(-5)),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '\$$minFare',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: FoxFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.cream,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _StepBtn('+', () => onFare(5)),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Gap.sm + Gap.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$matchCount',
                  style: const TextStyle(
                    color: FoxColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' offers match filters'),
              ],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: FoxColors.cream.withValues(alpha: 0.5),
              ),
            ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: on ? FoxColors.brandFox : FoxColors.cream.withValues(alpha: 0.15),
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
                BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(this.glyph, this.onTap);
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: FoxColors.cream.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: FoxColors.cream.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: const TextStyle(
            color: FoxColors.cream,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: Gap.sm + Gap.xs),
        const Expanded(child: Divider(color: FoxColors.border, height: 1)),
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});
  final OfferSummary offer;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(offer.verdict);
    final time =
        '${offer.seenAt.hour.toString().padLeft(2, '0')}:${offer.seenAt.minute.toString().padLeft(2, '0')}';
    return Container(
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
              color: style.color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                    color: style.color.withValues(alpha: 0.5), blurRadius: 8),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${offer.totalKm.toStringAsFixed(1)} km  '),
                      TextSpan(
                        text: '\$${offer.pricePerKm.toStringAsFixed(2)}/km',
                        style: const TextStyle(
                          color: FoxColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    style: const TextStyle(
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
                    ? '\$${offer.payout.toStringAsFixed(0)}'
                    : '\$${offer.payout.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: FoxFonts.display,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FoxColors.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.search_off,
            size: 36,
            color: FoxColors.textDisabled,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            filtered
                ? '$hiddenCount offers outside these filters'
                : 'No offers yet — go live and drive.',
            style: const TextStyle(
                fontSize: 13, color: FoxColors.textDisabled),
          ),
          if (filtered) ...[
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: onShowAll,
              style:
                  TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              child: const Text('Show all',
                  style: TextStyle(fontWeight: FontWeight.w700)),
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
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final OfferStats stats;

  /// `17` → "5 PM" (hour-of-day label for the busiest-hour stat).
  static String _hourLabel(int h) {
    final ampm = h < 12 ? 'AM' : 'PM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(Gap.md + Gap.xs),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'OFFERS',
              value: '${s.total}',
              sub: '${s.good}·${s.ok}·${s.bad}',
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'GOOD AVG',
              value: s.goodAvgPerKm > 0
                  ? '\$${s.goodAvgPerKm.toStringAsFixed(2)}'
                  : '—',
              sub: '/km',
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'BEST',
              value: s.best != null && s.best!.pricePerKm > 0
                  ? '\$${s.best!.pricePerKm.toStringAsFixed(2)}'
                  : '—',
              sub: s.best != null ? s.best!.platform.label : '',
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'BUSIEST',
              value: s.busiestHour != null ? _hourLabel(s.busiestHour!) : '—',
              sub: 'hour',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub});

  final String label;
  final String value;
  final String sub;

  static bool _isInt(String s) => int.tryParse(s) != null;
  static const _valueStyle = TextStyle(
    fontFamily: FoxFonts.display,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: FoxColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: FoxColors.textDisabled,
          ),
        ),
        const SizedBox(height: Gap.xs),
        _isInt(value)
            ? TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: int.parse(value)),
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : Motion.count,
                curve: Motion.curve,
                builder: (context, v, _) => Text('$v', style: _valueStyle),
              )
            : Text(value, style: _valueStyle),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 10.5,
            color: FoxColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
