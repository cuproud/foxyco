import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fox_settings.dart';

enum HistoryIntent {
  needsReview,
  goalWeek,
  goalMonth,
  goalQuarter,
  goalYear;

  EarningsGoalPeriod? get goalPeriod => switch (this) {
    HistoryIntent.needsReview => null,
    HistoryIntent.goalWeek => EarningsGoalPeriod.week,
    HistoryIntent.goalMonth => EarningsGoalPeriod.month,
    HistoryIntent.goalQuarter => EarningsGoalPeriod.quarter,
    HistoryIntent.goalYear => EarningsGoalPeriod.year,
  };

  static HistoryIntent forGoal(EarningsGoalPeriod period) => switch (period) {
    EarningsGoalPeriod.week => HistoryIntent.goalWeek,
    EarningsGoalPeriod.month => HistoryIntent.goalMonth,
    EarningsGoalPeriod.quarter => HistoryIntent.goalQuarter,
    EarningsGoalPeriod.year => HistoryIntent.goalYear,
  };
}

class PendingHistoryIntent extends Notifier<HistoryIntent?> {
  @override
  HistoryIntent? build() => null;

  void open(HistoryIntent intent) => state = intent;
  void clear() => state = null;
}

final pendingHistoryIntentProvider =
    NotifierProvider<PendingHistoryIntent, HistoryIntent?>(
      PendingHistoryIntent.new,
    );
