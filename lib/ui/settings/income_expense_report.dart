import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/expense_report.dart';
import '../../domain/offer_summary.dart';
import '../../domain/vehicle_expense.dart';
import '../theme/tokens.dart';

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
  ReportPeriod _period = ReportPeriod.month;
  late DateTime _date = widget.initialDate ?? DateTime.now();
  String _money(double value) =>
      '${widget.currency}${value.toStringAsFixed(2)}';
  void _move(int direction) => setState(() {
    final start = _period.start(_date);
    _date = DateTime(start.year, start.month + direction * _period.months);
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
      DateTime(report.start.year, report.start.month - _period.months),
    );
    final oldIncome = previous.stats.recordedEarnings;
    final change = oldIncome == 0
        ? null
        : (report.stats.recordedEarnings / oldIncome - 1) * 100;
    final locale = MaterialLocalizations.of(context);
    final title = switch (_period) {
      ReportPeriod.month => locale.formatMonthYear(report.start),
      ReportPeriod.quarter =>
        'Q${(report.start.month - 1) ~/ 3 + 1} · ${report.start.year}',
      ReportPeriod.year => '${report.start.year}',
    };
    final labels = _period == ReportPeriod.month
        ? [
            '1',
            '${(report.incomePoints.length - 1) ~/ 2 + 1}',
            '${report.incomePoints.length}',
          ]
        : [
            for (final month in [
              report.start.month,
              report.start.month + (_period.months - 1) ~/ 2,
              report.start.month + _period.months - 1,
            ])
              const [
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
              ][month - 1],
          ];
    Widget summary(
      String label,
      double value, {
      bool net = false,
      String? detail,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: net
                        ? FoxColors.textPrimary
                        : FoxColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Flexible(
                child: Text(
                  _money(value),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: net ? 21 : 15,
                    color: net
                        ? value < 0
                              ? VerdictColors.bad
                              : FoxColors.brandText
                        : FoxColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              detail,
              style: TextStyle(color: FoxColors.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.xs),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2,
            borderRadius: BorderRadius.circular(Radii.cardSm),
          ),
          child: Row(
            children: [
              for (final period in ReportPeriod.values)
                Expanded(
                  child: Semantics(
                    selected: _period == period,
                    child: TextButton(
                      onPressed: () => setState(() => _period = period),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        backgroundColor: _period == period
                            ? FoxColors.bgSurface
                            : null,
                        foregroundColor: _period == period
                            ? FoxColors.brandText
                            : FoxColors.textSecondary,
                      ),
                      child: Text(
                        period.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _period == period
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Next period',
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        GestureDetector(
          key: const Key('income-expenses-graph'),
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed.abs() > 100) _move(speed < 0 ? 1 : -1);
          },
          child: Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FoxColors.inkSoft, FoxColors.ink],
              ),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recorded income',
                  style: TextStyle(color: FoxColors.creamDim, fontSize: 12),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  _money(report.stats.recordedEarnings),
                  style: TextStyle(
                    color: FoxColors.brandText,
                    fontFamily: FoxFonts.display,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  change == null
                      ? 'No prior-period income to compare'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs previous period',
                  style: TextStyle(color: FoxColors.creamDim, fontSize: 11),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  '${_period == ReportPeriod.month ? 'Daily' : 'Monthly'} totals (${widget.currency})',
                  style: TextStyle(color: FoxColors.creamDim, fontSize: 11),
                ),
                const SizedBox(height: Gap.xs),
                Semantics(
                  label:
                      'Income and expense trend for $title. Income ${_money(report.stats.recordedEarnings)}. Expenses ${_money(report.costs)}. Swipe to change period.',
                  child: RepaintBoundary(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey((
                        report.start,
                        _period,
                        report.incomePoints.join(','),
                        report.expensePoints.join(','),
                      )),
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : Motion.count,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => CustomPaint(
                        size: Size(
                          double.infinity,
                          170 + MediaQuery.textScalerOf(context).scale(10) * 3,
                        ),
                        painter: _TrendPainter(
                          report.incomePoints,
                          report.expensePoints,
                          value,
                          FoxColors.brandText,
                          VerdictColors.ok,
                          labels,
                          MediaQuery.textScalerOf(context),
                          Directionality.of(context),
                          FoxColors.creamDim,
                          FoxColors.cream.withValues(alpha: .1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.xs,
                  children: [
                    for (final series in [
                      (
                        label: 'Income',
                        color: FoxColors.brandText,
                        dashed: false,
                      ),
                      (
                        label: 'Expenses',
                        color: VerdictColors.ok,
                        dashed: true,
                      ),
                    ])
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: Gap.md,
                            child: Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < (series.dashed ? 3 : 1);
                                  i++
                                )
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: EdgeInsets.only(
                                        right: series.dashed ? 2 : 0,
                                      ),
                                      color: series.color,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Text(
                            series.label,
                            style: TextStyle(
                              color: FoxColors.creamDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  report.stats.recordedEarnings == 0 && report.costs == 0
                      ? 'No recorded activity in this period'
                      : 'Swipe graph to explore periods',
                  style: TextStyle(color: FoxColors.creamDim, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: FoxColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary(
                'Final payouts',
                report.stats.confirmedEarnings,
                detail: 'Saved actual payouts, including cancellation fees.',
              ),
              summary(
                'Estimated payouts',
                report.stats.estimatedEarnings,
                detail: report.stats.missingFinalPayouts == 0
                    ? 'No accepted jobs awaiting a final payout.'
                    : '${report.stats.missingFinalPayouts} accepted ${report.stats.missingFinalPayouts == 1 ? 'job still uses its' : 'jobs still use their'} offered payout.',
              ),
              summary('Recorded expenses', report.costs),
              Divider(color: FoxColors.borderSoft),
              summary(
                'Report balance',
                report.balance,
                net: true,
                detail: 'Final + estimated payouts − recorded expenses.',
              ),
              const SizedBox(height: Gap.sm),
              FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense'),
              ),
            ],
          ),
        ),
        if (report.categories.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in report.categories.entries)
                  Container(
                    margin: const EdgeInsets.only(right: Gap.sm),
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.cardSm),
                      border: Border.all(color: FoxColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _money(entry.value),
                          style: TextStyle(
                            color: FoxColors.brandFox,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: FoxColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.sm),
        Text(
          'Update final payouts in History; edit costs under Vehicle expenses. Toll reimbursements are already included in payouts. Balance includes estimates and is not taxable profit.',
          style: TextStyle(color: FoxColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(
    this.income,
    this.expenses,
    this.progress,
    this.orange,
    this.gold,
    this.labels,
    this.textScaler,
    this.textDirection,
    this.labelColor,
    this.gridColor,
  );
  final List<double> income, expenses;
  final double progress;
  final Color orange, gold;
  final List<String> labels;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Color labelColor, gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = math.max(1.0, [...income, ...expenses].reduce(math.max));
    final magnitude = math.pow(10, (math.log(peak / 4) / math.ln10).floor());
    final step =
        [
          1,
          2,
          2.5,
          5,
          10,
        ].firstWhere((value) => value * magnitude >= peak / 4) *
        magnitude;
    final intervals = (peak / step).ceil();
    final ceiling = step * intervals;
    TextPainter label(String value) => TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontFamily: FoxFonts.sans,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final ticks = [
      for (var i = 0; i <= intervals; i++)
        label(
          (step * i).toStringAsFixed(
            step < 1
                ? 2
                : step < 10
                ? 1
                : 0,
          ),
        ),
    ];
    final left = ticks.map((text) => text.width).reduce(math.max) + Gap.sm;
    final labelHeight = ticks.first.height;
    final plot = Rect.fromLTRB(
      left,
      labelHeight / 2 + Gap.xs,
      size.width - Gap.xs,
      size.height - labelHeight - Gap.sm,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= intervals; i++) {
      final y = plot.bottom - i / intervals * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      ticks[i].paint(
        canvas,
        Offset(left - Gap.sm - ticks[i].width, y - labelHeight / 2),
      );
    }
    for (var i = 0; i < labels.length; i++) {
      final text = label(labels[i]);
      final index = i == 1
          ? (income.length - 1) ~/ 2
          : i == 0
          ? 0
          : income.length - 1;
      final x = plot.left + index / (income.length - 1) * plot.width;
      text.paint(
        canvas,
        Offset(
          (x - text.width / 2).clamp(plot.left, size.width - text.width),
          plot.bottom + Gap.sm,
        ),
      );
    }
    Path line(List<double> values) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = plot.left + i / (values.length - 1) * plot.width;
        final y = plot.bottom - values[i] / ceiling * plot.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        plot.left - 2,
        plot.top - 2,
        plot.left + plot.width * progress + 2,
        plot.bottom + 2,
      ),
    );
    final incomeLine = line(income);
    final area = Path.from(incomeLine)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [orange.withValues(alpha: .12), orange.withValues(alpha: 0)],
        ).createShader(plot),
    );
    canvas.drawPath(
      incomeLine,
      Paint()
        ..color = orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final expensePaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in line(expenses).computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          expensePaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.progress != progress ||
      old.income != income ||
      old.expenses != expenses ||
      old.orange != orange ||
      old.gold != gold ||
      old.labels != labels ||
      old.textScaler != textScaler ||
      old.textDirection != textDirection ||
      old.labelColor != labelColor ||
      old.gridColor != gridColor;
}
