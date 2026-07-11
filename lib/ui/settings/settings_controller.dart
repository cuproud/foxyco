import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/thresholds.dart';

/// Holds the user's [Thresholds] (the $/km cut points).
///
/// MVP note: seeded with [Thresholds.defaults] and kept in memory. Persistence
/// (SharedPreferences) lands with M3 — the public shape stays the same, only
/// [build] and the setters gain a read/write. The overlay isolate will read the
/// same persisted value, so edits here are the single source of truth.
class SettingsController extends Notifier<Thresholds> {
  @override
  Thresholds build() => Thresholds.defaults;

  /// GOOD cut. Clamped so it can never dip below the BAD cut (keeps the band
  /// coherent — see [Thresholds.isValid]); the slider also enforces this.
  void setGood(double value) {
    final clamped = value < state.badBelow ? state.badBelow : value;
    _set(state.copyWith(goodAtOrAbove: clamped));
  }

  /// BAD cut. Clamped so it can never rise above the GOOD cut.
  void setBad(double value) {
    final clamped = value > state.goodAtOrAbove ? state.goodAtOrAbove : value;
    _set(state.copyWith(badBelow: clamped));
  }

  void reset() => _set(Thresholds.defaults);

  void _set(Thresholds next) {
    state = next;
    if (kDebugMode) {
      debugPrint(
        'FoxyCo thresholds → GOOD ≥ ${next.goodAtOrAbove.toStringAsFixed(2)} · '
        'BAD < ${next.badBelow.toStringAsFixed(2)}',
      );
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, Thresholds>(SettingsController.new);
