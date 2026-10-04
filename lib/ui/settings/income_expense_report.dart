import 'dart:async';
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

class _IncomeBars extends StatelessWidget {
  const _IncomeBars({
    required this.income,
    required this.labels,
    required this.selected,
    required this.money,
    required this.onSelect,
  });

  final List<double> income;
  final List<String> labels;
  final int selected;
  final String Function(double) money;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
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
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 42,
                                          ),
                                          height: barHeight(i),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(13),
                                                  bottom: Radius.circular(4),
                                                ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: income[i] == 0
                                                  ? [
                                                      FoxColors.border,
                                                      FoxColors.border,
                                                    ]
                                                  : const [
                                                      Color(0xFFFFD45F),
                                                      Color(0xFFFFA065),
                                                      Color(0xFF7CE4BB),
                                                      Color(0xFF977EF0),
                                                    ],
                                            ),
                                            border: Border.all(
                                              color: i == selected
                                                  ? const Color(0xFFFFD599)
                                                  : Colors.transparent,
                                            ),
                                            boxShadow:
                                                i == selected && income[i] > 0
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF7CE4BB,
                                                      ).withValues(alpha: .25),
                                                      blurRadius: 20,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child:
                                              i == selected &&
                                                  barHeight(i) >= 55
                                              ? _BarSparkles(
                                                  key: ValueKey(
                                                    'sparkles-for-bar-$i',
                                                  ),
                                                )
                                              : null,
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

class _BarSparkles extends StatefulWidget {
  const _BarSparkles({super.key});

  @override
  State<_BarSparkles> createState() => _BarSparklesState();
}

class _BarSparklesState extends State<_BarSparkles> {
  Timer? _timer;
  int _cycle = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          !MediaQuery.disableAnimationsOf(context)) {
        setState(() => _cycle++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(_cycle),
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1300),
    curve: Curves.easeOut,
    builder: (context, progress, child) => LayoutBuilder(
      builder: (context, size) => CustomPaint(
        key: const Key('selected-bar-sparkles'),
        size: Size(size.maxWidth, size.maxHeight),
        painter: _SparklePainter(progress),
      ),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, radius, delay) in const [
      (.50, .14, 4.5, .00),
      (.20, .28, 3.3, .13),
      (.66, .39, 3.7, .27),
      (.34, .54, 4.0, .40),
      (.72, .68, 3.1, .53),
      (.43, .81, 3.6, .66),
    ]) {
      final phase = ((progress - delay) / .34).clamp(0.0, 1.0);
      final pulse = math.sin(phase * math.pi);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: .58 + pulse * .42);
      final cx = size.width * x;
      final cy = size.height * y - pulse * 6;
      final extent = radius * (1 + pulse * .25);
      final inner = extent * .2;
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
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      progress != oldDelegate.progress;
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
          detail: 'Actual and pending payout totals.',
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
            '$pendingCount accepted ${pendingCount == 1 ? 'job uses' : 'jobs use'} the offered payout until a final payout is saved.',
            style: TextStyle(color: FoxColors.textSecondary, fontSize: 11),
          ),
        ],
        Divider(height: Gap.lg + Gap.sm, color: FoxColors.borderSoft),
        _SnapshotRow(
          label: 'Expenses',
          detail: 'Tracked costs recorded under Vehicle expenses.',
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
