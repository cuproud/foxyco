import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/fox_settings.dart';
import '../../domain/offer_summary.dart';
import '../theme/tokens.dart';

extension on EarningsGoalPeriod {
  String get label => switch (this) {
    EarningsGoalPeriod.week => 'Week',
    EarningsGoalPeriod.month => 'Month',
    EarningsGoalPeriod.quarter => 'Quarter',
    EarningsGoalPeriod.year => 'Year',
  };

  (DateTime, DateTime) range(DateTime now) => switch (this) {
    EarningsGoalPeriod.week => () {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    }(),
    EarningsGoalPeriod.month => (
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ),
    EarningsGoalPeriod.quarter => () {
      final month = ((now.month - 1) ~/ 3) * 3 + 1;
      return (DateTime(now.year, month), DateTime(now.year, month + 3));
    }(),
    EarningsGoalPeriod.year => (DateTime(now.year), DateTime(now.year + 1)),
  };
}

class GoalCard extends StatefulWidget {
  const GoalCard({
    super.key,
    required this.offers,
    required this.settings,
    this.now,
    this.onGoalChanged,
  });

  final List<OfferSummary> offers;
  final FoxSettings settings;
  final DateTime? now;
  final void Function(EarningsGoalPeriod period, double amount)? onGoalChanged;

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  EarningsGoalPeriod _period = EarningsGoalPeriod.week;

  Future<void> _editGoal() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditGoalSheet(
        period: _period,
        amount: widget.settings.goalFor(_period),
        symbol: widget.settings.currency.symbol,
      ),
    );
    if (amount != null && mounted) widget.onGoalChanged?.call(_period, amount);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final (start, end) = _period.range(now);
    final earned = widget.offers
        .where(
          (offer) =>
              !offer.seenAt.isBefore(start) &&
              offer.seenAt.isBefore(end) &&
              (offer.outcome == OfferOutcome.taken ||
                  offer.outcome == OfferOutcome.completed),
        )
        .fold<double>(0, (total, offer) => total + offer.performancePayout);
    final target = widget.settings.goalFor(_period);
    final progress = (earned / target).clamp(0.0, 1.0);
    final left = math.max(0.0, target - earned);
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = math.max(1, end.difference(today).inDays);
    final daily = (left / daysLeft).ceil();
    final symbol = widget.settings.currency.symbol;
    final percent = (progress * 100).round();
    final message = switch (progress) {
      >= 1 => 'Goal reached. Nicely driven!',
      >= 0.8 => 'Almost there—just $symbol${left.ceil()} to go.',
      >= 0.5 => 'You’re past halfway. Keep it rolling.',
      _ => 'One good trip at a time.',
    };

    return Container(
      key: const ValueKey('home-goal-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FoxColors.bgSurface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: FoxColors.borderSoft),
        boxShadow: Shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_period.label}ly goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: FoxColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (widget.onGoalChanged != null)
                      TextButton.icon(
                        key: const ValueKey('edit-goal'),
                        onPressed: _editGoal,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Recorded earnings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Gap.sm + Gap.xs),
                _PeriodTabs(
                  selected: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$symbol${_amount(earned)}',
                                style: TextStyle(
                                  color: FoxColors.brandText,
                                  fontFamily: FoxFonts.display,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                ),
                              ),
                              TextSpan(
                                text: '  of $symbol${_amount(target)}',
                                style: TextStyle(
                                  color: FoxColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Semantics(
                      label: 'Goal progress',
                      value: '$percent%',
                      child: Container(
                        key: const ValueKey('goal-progress'),
                        width: 76,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FoxColors.brandFox.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: FoxColors.brandFox.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            color: FoxColors.brandText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 1350),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => _GoalRoad(progress: value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: progress >= 1
                        ? VerdictColors.good
                        : FoxColors.brandText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    _GoalStat(
                      value: '$symbol${_amount(left)}',
                      label: 'left to earn',
                    ),
                    _GoalStat(value: '$daysLeft', label: 'days left'),
                    _GoalStat(value: '$symbol$daily', label: 'per day to goal'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final EarningsGoalPeriod selected;
  final ValueChanged<EarningsGoalPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FoxColors.bgSurface2,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: EarningsGoalPeriod.values.map((period) {
            final active = period == selected;
            return Expanded(
              child: Semantics(
                selected: active,
                button: true,
                child: InkWell(
                  key: ValueKey('goal-${period.name}'),
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? FoxColors.bgSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active
                            ? FoxColors.textPrimary
                            : FoxColors.textSecondary,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _GoalRoad extends StatelessWidget {
  const _GoalRoad({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: LayoutBuilder(
        builder: (_, constraints) => Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GoalRoadPainter(progress)),
            ),
            Positioned(
              left: constraints.maxWidth * (0.08 + progress * 0.68) - 57,
              bottom: 25,
              width: 114,
              child: Image.asset(
                'assets/branding/foxy_goal_car.webp',
                semanticLabel: 'Fox driving toward the earnings goal',
              ),
            ),
            if (progress >= 1)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF183D2A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '✓ Goal reached',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalRoadPainter extends CustomPainter {
  const _GoalRoadPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 400;
    final sy = size.height / 142;
    canvas.save();
    canvas.scale(sx, sy);
    final paint = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 142),
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDCE9EC), Color(0xFFF5DED0), Color(0xFFDCCFAE)],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 142)),
    );
    canvas.drawCircle(
      const Offset(340, 28),
      18,
      Paint()..color = const Color(0xFFFFD48A),
    );
    _path(canvas, const Color(0xFFB9C9C1), const [
      Offset(0, 92),
      Offset(52, 52),
      Offset(78, 73),
      Offset(132, 27),
      Offset(194, 82),
      Offset(246, 45),
      Offset(304, 79),
      Offset(350, 37),
      Offset(400, 80),
      Offset(400, 110),
      Offset(0, 110),
    ]);
    _path(canvas, const Color(0xFF82998D), const [
      Offset(0, 101),
      Offset(65, 75),
      Offset(113, 97),
      Offset(170, 65),
      Offset(230, 97),
      Offset(287, 68),
      Offset(338, 93),
      Offset(400, 71),
      Offset(400, 110),
      Offset(0, 110),
    ]);
    for (final x in const [18.0, 58.0, 320.0, 375.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x, 69, 4, 25),
        Paint()..color = const Color(0xFF536F60),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 2, 67), width: 18, height: 25),
        Paint()..color = const Color(0xFF668476),
      );
    }
    final road = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-18, 90, 436, 42),
      const Radius.circular(14),
    );
    canvas.drawRRect(road, Paint()..color = const Color(0xFF2B3231));
    canvas.drawRect(
      Rect.fromLTWH(0, 127, 400 * progress, 2),
      Paint()..color = const Color(0xFFFF7754),
    );
    for (var x = -12.0; x < 410; x += 36) {
      canvas.drawRect(
        Rect.fromLTWH(x, 110, 21, 2),
        Paint()..color = const Color(0xFFF8DDB0),
      );
    }
    for (final milestone in const [0.25, 0.5, 0.75]) {
      canvas.drawCircle(
        Offset(400 * milestone, 111),
        5,
        Paint()
          ..color = progress >= milestone
              ? FoxColors.brandFox
              : const Color(0xFF777F79),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(374, 50, 2, 40),
      Paint()..color = const Color(0xFF5A625C),
    );
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 3; x++) {
        canvas.drawRect(
          Rect.fromLTWH(376 + x * 7, 50 + y * 7, 7, 7),
          Paint()
            ..color = (x + y).isEven ? Colors.white : const Color(0xFF222222),
        );
      }
    }
    canvas.restore();
  }

  void _path(Canvas canvas, Color color, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GoalRoadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GoalStat extends StatelessWidget {
  const _GoalStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(left: Gap.sm),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: FoxColors.borderSoft)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: FoxColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(color: FoxColors.textSecondary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditGoalSheet extends StatefulWidget {
  const _EditGoalSheet({
    required this.period,
    required this.amount,
    required this.symbol,
  });

  final EarningsGoalPeriod period;
  final double amount;
  final String symbol;

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.amount == widget.amount.roundToDouble()
          ? widget.amount.round().toString()
          : widget.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _value() => double.tryParse(_controller.text.replaceAll(',', '.'));

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _value());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.lg,
          Gap.lg,
          Gap.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit ${widget.period.label.toLowerCase()} goal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                key: const ValueKey('goal-amount'),
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return RegExp(
                          r'^\d{0,6}([.,]\d{0,2})?$',
                        ).hasMatch(newValue.text)
                        ? newValue
                        : oldValue;
                  }),
                ],
                decoration: InputDecoration(
                  labelText: 'Goal amount',
                  prefixText: widget.symbol,
                  helperText: 'Maximum ${widget.symbol}999,999.99',
                ),
                validator: (_) {
                  final value = _value();
                  if (value == null || value < 1 || value > 999999.99) {
                    return 'Enter an amount from 1 to 999,999.99';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: Gap.lg),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: Gap.sm,
                overflowSpacing: Gap.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('save-goal'),
                    onPressed: _save,
                    child: const Text('Save goal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
