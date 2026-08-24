import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HistoryIntent { needsReview }

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
