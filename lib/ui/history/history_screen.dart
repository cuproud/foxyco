import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../services/offer_log.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// History (references/foxyco_history.html).
///
/// Time range + per-app chips + a "top offers only" filter over the live
/// offer log ([offerLogProvider]) — every scored offer FoxyCo has seen.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Range { today, week, month, all }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Range _range = _Range.today;
  final Set<GigPlatform?> _apps = {null}; // null == "All"
  bool _topOnly = false;
  int _minFare = 20;

  int _daysAgo(DateTime t) =>
      DateTime.now().difference(DateTime(t.year, t.month, t.day)).inDays;

  bool _passes(OfferSummary o) {
    final d = _daysAgo(o.seenAt);
    switch (_range) {
      case _Range.today:
        if (d != 0) return false;
      case _Range.week:
        if (d > 7) return false;
      case _Range.month:
        if (d > 30) return false;
      case _Range.all:
        break;
    }
    if (!_apps.contains(null) && !_apps.contains(o.platform)) return false;
    if (_topOnly && !(o.verdict == Verdict.good && o.payout >= _minFare)) {
      return false;
    }
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
              '${all.length} offers',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: FoxColors.textDisabled,
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
          const _Empty()
        else
          ..._grouped(filtered),
      ],
    );
  }

  void _toggleApp(GigPlatform? app) {
    setState(() {
      if (app == null) {
        _apps
          ..clear()
          ..add(null);
        return;
      }
      _apps.remove(null);
      _apps.contains(app) ? _apps.remove(app) : _apps.add(app);
      if (_apps.isEmpty) _apps.add(null);
    });
  }

  /// Rows with a date header before each new day (skipped while top-only, where
  /// the list is a flat best-first ranking).
  List<Widget> _grouped(List<OfferSummary> offers) {
    if (_topOnly) {
      return offers.map((o) => _OfferRow(offer: o)).toList();
    }
    final out = <Widget>[];
    String? lastLabel;
    for (final o in offers) {
      final label = _dateLabel(o.seenAt);
      if (label != lastLabel) {
        out.add(Padding(
          padding: EdgeInsets.only(top: lastLabel == null ? 0 : Gap.md, bottom: Gap.sm),
          child: _DateHeader(label),
        ));
        lastLabel = label;
      }
      out.add(_OfferRow(offer: o));
    }
    return out;
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
  final _Range value;
  final ValueChanged<_Range> onChanged;

  static const _labels = {
    _Range.today: 'Today',
    _Range.week: '7 Days',
    _Range.month: '30 Days',
    _Range.all: 'All',
  };

  @override
  Widget build(BuildContext context) {
    final items = _Range.values;
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
                  color: FoxColors.ink,
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

  static const _appColor = {
    GigPlatform.uber: FoxColors.uber,
    GigPlatform.lyft: FoxColors.lyft,
    GigPlatform.hopp: FoxColors.hopp,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        _chip(null, 'All', null),
        for (final p in const [
          GigPlatform.uber,
          GigPlatform.lyft,
          GigPlatform.hopp,
        ])
          _chip(p, p.label, _appColor[p]),
      ],
    );
  }

  Widget _chip(GigPlatform? app, String label, Color? dot) {
    final active = selected.contains(app);
    return GestureDetector(
      onTap: () => onToggle(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? FoxColors.ink : FoxColors.bgSurface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
              color: active ? FoxColors.ink : FoxColors.borderSoft),
          boxShadow: active ? null : Shadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
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
                  color: Color(0xFFFFB25C), size: 20),
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
                      on ? 'GOOD offers over \$$minFare' : 'Best \$/km, all fares',
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

  static const _appColor = {
    GigPlatform.uber: FoxColors.uber,
    GigPlatform.lyft: FoxColors.lyft,
    GigPlatform.hopp: FoxColors.hopp,
  };

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
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _appColor[offer.platform] ?? FoxColors.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      offer.platform.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FoxColors.ink,
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
                          color: FoxColors.ink,
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
                  color: FoxColors.ink,
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 36, color: FoxColors.textDisabled),
          SizedBox(height: Gap.sm),
          Text(
            'No offers match these filters',
            style: TextStyle(fontSize: 13, color: FoxColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
