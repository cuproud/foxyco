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
  static const _cream = Color(0xfffff8e8);
  static const _muted = Color(0xffb9c2bc);
  static const _gold = Color(0xffd8aa57);
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
        ? ['1', '15', '${report.incomePoints.length}']
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
    Widget summary(String label, double value, {bool net = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: net ? FoxColors.textPrimary : FoxColors.textSecondary,
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
                color: net ? FoxColors.brandFox : FoxColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
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
                            ? FoxColors.brandFox
                            : FoxColors.textSecondary,
                      ),
                      child: Text(
                        period.label,
                        style: const TextStyle(fontSize: 12),
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
              gradient: const RadialGradient(
                center: Alignment.topRight,
                radius: 1.4,
                colors: [Color(0xff433126), Color(0xff172a24)],
              ),
              boxShadow: Shadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Recorded income', style: TextStyle(color: _muted)),
                Text(
                  _money(report.stats.recordedEarnings),
                  style: TextStyle(
                    color: FoxColors.brandFox,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  change == null
                      ? 'No prior-period income to compare'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs previous period',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: Gap.md),
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
                          : const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => CustomPaint(
                        size: const Size(double.infinity, 170),
                        painter: _TrendPainter(
                          report.incomePoints,
                          report.expensePoints,
                          value,
                          FoxColors.brandFox,
                          _gold,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in labels)
                      Text(
                        label,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                const Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Text(
                      '━ Income',
                      style: TextStyle(color: _cream, fontSize: 12),
                    ),
                    Text(
                      '┄ Expenses',
                      style: TextStyle(color: _gold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  report.stats.recordedEarnings == 0 && report.costs == 0
                      ? 'No recorded activity in this period'
                      : 'Swipe graph to explore periods',
                  style: const TextStyle(color: _muted, fontSize: 11),
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
              summary('Final payouts', report.stats.confirmedEarnings),
              summary('Estimated payouts', report.stats.estimatedEarnings),
              summary('Recorded expenses', report.costs),
              Divider(color: FoxColors.borderSoft),
              summary('Report balance', report.balance, net: true),
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
          'History payouts include recorded cancellation fees and toll reimbursements. Estimated payouts are not final. Edit costs in Vehicle expenses below; the report updates automatically. Balance is not taxable profit.',
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
  );
  final List<double> income, expenses;
  final double progress;
  final Color orange, gold;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = math.max(1.0, [...income, ...expenses].reduce(math.max));
    final bottom = size.height - 6;
    final top = 22.0;
    final plotHeight = bottom - top;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = bottom - i / 3 * plotHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: (peak * i / 3).toStringAsFixed(0),
          style: const TextStyle(color: Color(0xffb9c2bc), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 12));
    }
    Path line(List<double> values) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = i / (values.length - 1) * size.width;
        final y = bottom - values[i] / peak * plotHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final incomeLine = line(income);
    final area = Path.from(incomeLine)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [orange.withValues(alpha: .28), orange.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      incomeLine,
      Paint()
        ..color = orange.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      incomeLine,
      Paint()
        ..color = orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final expensePaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
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
      old.gold != gold;
}
