import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/expense_report.dart';
import '../../domain/offer_summary.dart';
import '../../domain/vehicle_expense.dart';
import '../theme/tokens.dart';

/// The Garage income chart and payout snapshot.
class IncomeExpenseReport extends StatefulWidget {
  const IncomeExpenseReport({
    super.key,
    required this.offers,
    required this.expenses,
    required this.currency,
    required this.onAdd,
    this.initialDate,
  });

  final List<OfferSummary> offers;
  final List<VehicleExpense> expenses;
  final String currency;
  final VoidCallback onAdd;
  final DateTime? initialDate;

  @override
  State<IncomeExpenseReport> createState() => _IncomeExpenseReportState();
}

class _IncomeExpenseReportState extends State<IncomeExpenseReport> {
  ReportPeriod _period = ReportPeriod.week;
  int? _selectedIndex;
  late DateTime _date = widget.initialDate ?? DateTime.now();

  String _money(double value) =>
      '${widget.currency}${value.toStringAsFixed(2)}';

  void _move(int direction) => setState(() {
    _date = _period.move(_date, direction);
    _selectedIndex = null;
  });

  @override
  Widget build(BuildContext context) {
    final report = ExpenseReport(
      widget.offers,
      widget.expenses,
      _period,
      _date,
    );
    final previous = ExpenseReport(
      widget.offers,
      widget.expenses,
      _period,
      _period.move(_date, -1),
    );
    final prior = previous.stats.recordedEarnings;
    final change = prior <= 0
        ? null
        : (report.stats.recordedEarnings / prior - 1) * 100;
    final comparisonPeriod = switch (_period) {
      ReportPeriod.week => 'last week',
      ReportPeriod.month => 'last month',
      ReportPeriod.quarter => 'last quarter',
      ReportPeriod.year => 'last year',
    };
    final locale = MaterialLocalizations.of(context);
    final title = switch (_period) {
      ReportPeriod.week =>
        '${locale.formatShortDate(report.start)} – ${locale.formatShortDate(report.end.subtract(const Duration(days: 1)))}',
      ReportPeriod.month => locale.formatMonthYear(report.start),
      ReportPeriod.quarter =>
        'Q${(report.start.month - 1) ~/ 3 + 1} · ${report.start.year}',
      ReportPeriod.year => '${report.start.year}',
    };
    final points = _chartPoints(report);
    final selected = (_selectedIndex ?? _latestPoint(points.$1)).clamp(
      0,
      points.$1.length - 1,
    );
    Widget periodTab(ReportPeriod option) => Semantics(
      selected: option == _period,
      child: TextButton(
        onPressed: () => setState(() {
          _period = option;
          _selectedIndex = null;
        }),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          backgroundColor: option == _period
              ? FoxColors.brandFox
              : Colors.transparent,
          foregroundColor: option == _period
              ? Colors.white
              : FoxColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          option.label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: const Key('income-expenses-graph'),
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed.abs() > 100) _move(speed < 0 ? 1 : -1);
          },
          child: Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [FoxColors.inkSoft, FoxColors.ink],
              ),
              border: Border.all(color: FoxColors.borderSoft),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total income',
                          style: TextStyle(
                            color: FoxColors.creamDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: Gap.xs),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: math.max(
                              120,
                              MediaQuery.sizeOf(context).width - 100,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _money(report.stats.recordedEarnings),
                              style: TextStyle(
                                color: FoxColors.brandFox,
                                fontFamily: FoxFonts.display,
                                fontSize:
                                    MediaQuery.textScalerOf(context).scale(1) >
                                        1.5
                                    ? 28
                                    : 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                height: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: FoxColors.brandFox.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            change == null
                                ? '—'
                                : '${change >= 0 ? '↗ +' : '↘ '}${change.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: FoxColors.brandText,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          change == null
                              ? 'No $comparisonPeriod income'
                              : 'vs $comparisonPeriod',
                          style: TextStyle(
                            color: FoxColors.creamDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: FoxColors.bgSurface2,
                    borderRadius: BorderRadius.circular(Radii.cardSm),
                    border: Border.all(color: FoxColors.borderSoft),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final fits =
                          constraints.maxWidth >= 280 &&
                          MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                      final row = Row(
                        children: [
                          for (final option in ReportPeriod.values)
                            if (fits)
                              Expanded(child: periodTab(option))
                            else
                              periodTab(option),
                        ],
                      );
                      return fits
                          ? row
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: row,
                            );
                    },
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous period',
                      onPressed: () => _move(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FoxColors.creamDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next period',
                      onPressed: () => _move(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                Semantics(
                  label:
                      'Income trend for $title. Income ${_money(report.stats.recordedEarnings)}. Swipe to change period.',
                  child: _IncomeBars(
                    income: points.$1,
                    labels: points.$2,
                    selected: selected,
                    periodKey: (_period, report.start),
                    money: _money,
                    onSelect: (index) => setState(() => _selectedIndex = index),
                  ),
                ),
                if (report.stats.recordedEarnings == 0)
                  Text(
                    'No recorded income in this period',
                    style: TextStyle(color: FoxColors.creamDim, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SnapshotCard(
          finalPayouts: _money(report.stats.confirmedEarnings),
          estimatedPayouts: _money(report.stats.estimatedEarnings),
          payouts: _money(report.stats.recordedEarnings),
          expenses: _money(report.costs),
          balance: _money(report.balance),
          negativeBalance: report.balance < 0,
          pendingCount: report.stats.missingFinalPayouts,
          onAdd: widget.onAdd,
        ),
        if (report.categories.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final category in report.categories.entries)
                Chip(
                  label: Text('${category.key} · ${_money(category.value)}'),
                  backgroundColor: FoxColors.bgSurface2,
                  side: BorderSide(color: FoxColors.borderSoft),
                ),
            ],
          ),
        ],
      ],
    );
  }

  int _latestPoint(List<double> points) {
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i] > 0) return i;
    }
    return points.length - 1;
  }

  (List<double>, List<String>) _chartPoints(ExpenseReport report) {
    if (_period == ReportPeriod.week) {
      return (
        report.incomePoints,
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
    }
    if (_period == ReportPeriod.month) {
      final count = (report.incomePoints.length / 7).ceil();
      final income = List<double>.filled(count, 0);
      for (var i = 0; i < report.incomePoints.length; i++) {
        income[i ~/ 7] += report.incomePoints[i];
      }
      return (income, [for (var i = 0; i < count; i++) 'W${i + 1}']);
    }
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
    return (
      report.incomePoints,
      [
        for (var i = 0; i < report.incomePoints.length; i++)
          months[report.start.month - 1 + i],
      ],
    );
  }
}

class _IncomeBars extends StatefulWidget {
  const _IncomeBars({
    required this.income,
    required this.labels,
    required this.selected,
    required this.periodKey,
    required this.money,
    required this.onSelect,
  });

  final List<double> income;
  final List<String> labels;
  final int selected;
  final Object periodKey;
  final String Function(double) money;
  final ValueChanged<int> onSelect;

  @override
  State<_IncomeBars> createState() => _IncomeBarsState();
}

class _IncomeBarsState extends State<_IncomeBars>
    with SingleTickerProviderStateMixin {
  // One clock survives bar selection, period changes and parent rebuilds.
  // Individual reflections use their own durations and phase offsets.
  static const _clockDuration = Duration(days: 1);
  late final AnimationController _lightClock = AnimationController(
    vsync: this,
    duration: _clockDuration,
    value: .000071,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _IncomeBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final peak = math.max(1.0, widget.income.reduce(math.max));
    final plotHeight = MediaQuery.textScalerOf(context).scale(1) > 1.5
        ? 145.0
        : 172.0;
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        widget.income[widget.selected] / peak * plotHeight >= 55;
    if (enabled && !_lightClock.isAnimating) {
      _lightClock.repeat();
    } else if (!enabled) {
      _lightClock.stop();
    }
  }

  @override
  void dispose() {
    _lightClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final income = widget.income;
    final labels = widget.labels;
    final selected = widget.selected;
    final money = widget.money;
    final onSelect = widget.onSelect;
    final peak = math.max(1.0, income.reduce(math.max));
    final plotHeight = MediaQuery.textScalerOf(context).scale(1) > 1.5
        ? 145.0
        : 172.0;
    double barHeight(int index) => income[index] == 0
        ? 5
        : math.max(12, income[index] / peak * plotHeight);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const labelWidth = 76.0;
            const labelHeight = 24.0;
            const plotTop = 32.0;
            final slot = constraints.maxWidth / income.length;
            final barCenter = slot * (selected + .5);
            final labelLeft = (barCenter - labelWidth / 2)
                .clamp(0.0, math.max(0, constraints.maxWidth - labelWidth))
                .toDouble();
            final labelTop = math.max(
              0.0,
              plotTop + plotHeight - barHeight(selected) - labelHeight - 5,
            );
            return SizedBox(
              height: plotTop + plotHeight,
              child: Stack(
                children: [
                  Positioned(
                    top: plotTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final fraction in [.2, .5, .8])
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: plotHeight * fraction,
                            child: Container(
                              height: 1,
                              color: FoxColors.borderSoft,
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < income.length; i++)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: i == selected,
                                  label:
                                      '${labels[i]} income ${money(income[i])}',
                                  child: InkWell(
                                    key: ValueKey('income-bar-$i'),
                                    onTap: () => onSelect(i),
                                    borderRadius: BorderRadius.circular(15),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: _IncomeBar(
                                          index: i,
                                          height: barHeight(i),
                                          hasIncome: income[i] > 0,
                                          selected: i == selected,
                                          periodKey: widget.periodKey,
                                          clock: _lightClock,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    key: const Key('selected-income-amount'),
                    left: labelLeft,
                    top: labelTop,
                    width: labelWidth,
                    height: labelHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF151819),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: Shadows.soft,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            money(income[selected]),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: barCenter - 7,
                    top: labelTop + labelHeight - 3,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: Color(0xFF151819),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: i == selected ? FoxColors.cream : FoxColors.creamDim,
                    fontSize: labels.length > 7 ? 9 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _IncomeBar extends StatelessWidget {
  const _IncomeBar({
    required this.index,
    required this.height,
    required this.hasIncome,
    required this.selected,
    required this.periodKey,
    required this.clock,
  });

  final int index;
  final double height;
  final bool hasIncome, selected;
  final Object periodKey;
  final Animation<double> clock;

  static const _radius = BorderRadius.vertical(
    top: Radius.circular(13),
    bottom: Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: selected ? 1 : 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        key: ValueKey('income-bar-clip-$index'),
        borderRadius: _radius,
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: selected && height >= 55
              ? _BarSparkles(
                  key: ValueKey((periodKey, index)),
                  clock: clock,
                  reducedMotion: reducedMotion,
                )
              : const SizedBox.expand(),
        ),
      ),
      builder: (context, selection, child) => Transform.scale(
        key: ValueKey('income-bar-lift-$index'),
        scale: 1 + .025 * selection,
        alignment: Alignment.bottomCenter,
        child: Container(
          key: ValueKey('income-bar-fill-$index'),
          constraints: const BoxConstraints(maxWidth: 42),
          height: height,
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: hasIncome
                  ? const [
                      Color(0xFFFFD45F),
                      Color(0xFFFFA065),
                      Color(0xFF7CE4BB),
                      Color(0xFF977EF0),
                    ]
                  : [FoxColors.border, FoxColors.border],
            ),
            border: Border.all(
              color: const Color(0xFFFFA065).withValues(alpha: selection),
              width: 1 + .5 * selection,
            ),
            boxShadow: hasIncome && selection > 0
                ? [
                    BoxShadow(
                      color: FoxColors.brandFox.withValues(
                        alpha: .16 * selection,
                      ),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFF7CE4BB,
                      ).withValues(alpha: .25 * selection),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BarSparkles extends StatelessWidget {
  const _BarSparkles({
    super.key,
    required this.clock,
    required this.reducedMotion,
  });

  final Animation<double> clock;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.expand(
      child: CustomPaint(
        key: const Key('selected-bar-sparkles'),
        painter: _SparklePainter(clock, reducedMotion: reducedMotion),
      ),
    ),
  );
}

class _SparkleSpec {
  const _SparkleSpec(
    this.x,
    this.y,
    this.size,
    this.phaseOffset,
    this.scaleOffset,
    this.durationMs,
    this.star,
  );

  final double x, y, size;
  final double phaseOffset, scaleOffset;
  final int durationMs;
  final bool star;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.clock, {required this.reducedMotion})
    : super(repaint: reducedMotion ? null : clock);

  final Animation<double> clock;
  final bool reducedMotion;

  // Scatter once, keeping positions and phases stable across widget rebuilds.
  // Uneven anchor groups avoid a column of equally spaced, sequential stars.
  static final _sparkles = (() {
    final random = math.Random(4816);
    const anchors = [
      (.29, .21),
      (.65, .71),
      (.73, .16),
      (.32, .88),
      (.44, .44),
      (.73, .53),
      (.26, .60),
    ];
    return [
      for (var i = 0; i < anchors.length; i++)
        _SparkleSpec(
          anchors[i].$1 + (random.nextDouble() - .5) * .12,
          anchors[i].$2 + (random.nextDouble() - .5) * .08,
          i < 2 ? (i == 0 ? 9 : 7.8) : 2.2 + random.nextDouble() * 2.0,
          random.nextDouble(),
          (random.nextDouble() - .5) * .60,
          1800 + random.nextInt(1001),
          i < 2,
        ),
    ];
  })();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(13),
      topRight: const Radius.circular(13),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(rounded);
    // A narrow inner rim makes the selected gradient read as illuminated glass.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .26),
            Colors.white.withValues(alpha: .06),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .12),
            Colors.white.withValues(alpha: .22),
          ],
          stops: const [0, .15, .50, .80, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rounded.deflate(.7),
      Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    final elapsedMs =
        clock.value * _IncomeBarsState._clockDuration.inMilliseconds;
    final reflections = reducedMotion
        ? [_sparkles[0], _sparkles[1], _sparkles[3], _sparkles[4]]
        : _sparkles;
    for (final sparkle in reflections) {
      double opacity;
      double scale;
      if (reducedMotion) {
        opacity = sparkle.star ? .65 : .48;
        scale = sparkle.star ? .85 : .90;
      } else {
        final phase =
            (elapsedMs / sparkle.durationMs + sparkle.phaseOffset) % 1;
        if (phase < .16) {
          opacity = .9 * Curves.easeOut.transform(phase / .16);
        } else if (phase < .83) {
          opacity = .9 - .55 * (phase - .16) / .67;
        } else {
          opacity = .35 * (1 - (phase - .83) / .17);
        }
        // Scale has its own phase, so brightness and size don't peak together.
        final scalePhase = (phase + sparkle.scaleOffset) % 1;
        if (scalePhase < .38) {
          scale = .45 + .55 * Curves.easeOut.transform(scalePhase / .38);
        } else if (scalePhase < .88) {
          scale =
              1 - .35 * Curves.easeInOut.transform((scalePhase - .38) / .50);
        } else {
          scale =
              .65 - .20 * Curves.easeInOut.transform((scalePhase - .88) / .12);
        }
      }
      final center = Offset(size.width * sparkle.x, size.height * sparkle.y);
      final extent = sparkle.size * scale * math.min(1, size.width / 24) / 2;
      final glowRadius = extent * 2.3;
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity * .18),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
      );
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
      if (!sparkle.star) {
        canvas.drawCircle(center, extent, paint);
        continue;
      }
      final cx = center.dx;
      final cy = center.dy;
      final inner = extent * .22;
      final star = Path()
        ..moveTo(cx, cy - extent)
        ..lineTo(cx + inner, cy - inner)
        ..lineTo(cx + extent, cy)
        ..lineTo(cx + inner, cy + inner)
        ..lineTo(cx, cy + extent)
        ..lineTo(cx - inner, cy + inner)
        ..lineTo(cx - extent, cy)
        ..lineTo(cx - inner, cy - inner)
        ..close();
      canvas.drawPath(star, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      clock != oldDelegate.clock || reducedMotion != oldDelegate.reducedMotion;
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.finalPayouts,
    required this.estimatedPayouts,
    required this.payouts,
    required this.expenses,
    required this.balance,
    required this.negativeBalance,
    required this.pendingCount,
    required this.onAdd,
  });

  final String finalPayouts, estimatedPayouts, payouts, expenses, balance;
  final bool negativeBalance;
  final int pendingCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.md),
    decoration: BoxDecoration(
      color: FoxColors.bgSurface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: FoxColors.borderSoft),
      boxShadow: Shadows.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SnapshotRow(
          label: 'Payouts',
          detail: 'Final + estimated',
          value: payouts,
        ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            _PayoutPill(label: 'Final · $finalPayouts', highlighted: true),
            _PayoutPill(label: 'Estimated · $estimatedPayouts'),
          ],
        ),
        if (pendingCount > 0) ...[
          const SizedBox(height: Gap.xs),
          Text(
            '$pendingCount ${pendingCount == 1 ? 'job needs' : 'jobs need'} final pay',
            style: TextStyle(color: FoxColors.textSecondary, fontSize: 11),
          ),
        ],
        Divider(height: Gap.lg + Gap.sm, color: FoxColors.borderSoft),
        _SnapshotRow(
          label: 'Expenses',
          detail: 'Vehicle costs',
          value: expenses,
        ),
        Divider(height: Gap.lg + Gap.sm, color: FoxColors.borderSoft),
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FoxColors.bgSurface2.withValues(alpha: .55),
                FoxColors.brandFox.withValues(alpha: .09),
              ],
            ),
            border: Border.all(color: FoxColors.borderSoft),
          ),
          child: _SnapshotRow(
            label: 'Report balance',
            detail: 'Payouts minus recorded expenses.',
            value: balance,
            emphasized: true,
            valueColor: negativeBalance
                ? VerdictColors.bad
                : FoxColors.brandText,
          ),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: FoxColors.brandFox,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add expense'),
        ),
      ],
    ),
  );
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.label,
    required this.detail,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label, detail, value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final amount = Text(
      value,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: valueColor ?? FoxColors.textPrimary,
        fontSize: emphasized ? 28 : 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -.7,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: FoxColors.textPrimary,
            fontSize: emphasized ? 16 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          detail,
          style: TextStyle(
            color: FoxColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 240 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              description,
              const SizedBox(height: Gap.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: amount),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: emphasized ? 52 : 58, child: description),
            const SizedBox(width: Gap.sm),
            Expanded(
              flex: emphasized ? 48 : 42,
              child: Align(
                alignment: Alignment.topRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: amount,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PayoutPill extends StatelessWidget {
  const _PayoutPill({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: highlighted
          ? FoxColors.brandFox.withValues(alpha: .11)
          : FoxColors.bgSurface2,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(
        color: highlighted
            ? FoxColors.brandFox.withValues(alpha: .25)
            : FoxColors.borderSoft,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: FoxColors.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}
