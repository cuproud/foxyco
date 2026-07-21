import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/fox_settings.dart';
import '../../domain/overlay_payload.dart' show PillSize;
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';

/// Holds every driver-tunable knob ([FoxSettings]) and persists it as one
/// SharedPreferences JSON blob. The overlay isolate gets the values it needs
/// via the shareData payload, so this stays the single source of truth.
///
/// Off-device (widget tests) the prefs channel isn't registered; loads fail
/// soft to defaults and saves are best-effort, so tests see [FoxSettings.defaults].
class SettingsController extends Notifier<FoxSettings> {
  static const _prefsKey = 'foxyco.settings.v1';

  @override
  FoxSettings build() {
    _load();
    return FoxSettings.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = FoxSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo settings load skipped: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo settings save skipped: $e');
    }
  }

  void _set(FoxSettings next) {
    state = next;
    _save();
  }

  /// GOOD cut for the ACTIVE rate mode. Clamped so it can never dip below the
  /// BAD cut (keeps the band coherent — see [Thresholds.isValid]); the slider
  /// also enforces this.
  void setGood(double value) {
    final t = state.activeThresholds;
    final clamped = value < t.badBelow ? t.badBelow : value;
    _setActive(t.copyWith(goodAtOrAbove: clamped));
  }

  /// BAD cut for the ACTIVE rate mode. Clamped so it can never rise above the
  /// GOOD cut.
  void setBad(double value) {
    final t = state.activeThresholds;
    final clamped = value > t.goodAtOrAbove ? t.goodAtOrAbove : value;
    _setActive(t.copyWith(badBelow: clamped));
  }

  /// Write [next] into whichever thresholds pair the active mode uses.
  void _setActive(Thresholds next) => _set(switch (state.rateMode) {
    RateMode.perKm => state.copyWith(thresholds: next),
    RateMode.perHour => state.copyWith(hourThresholds: next),
  });

  /// Apply a whole cut-point pair at once (threshold presets — onboarding and
  /// the Settings preset chips). Ignores invalid pairs.
  void applyPreset(Thresholds t) {
    if (t.isValid) _setActive(t);
  }

  /// Score by $/km or $/hr. Each mode keeps its own cut points.
  void setRateMode(RateMode mode) => _set(state.copyWith(rateMode: mode));

  /// Pickup-near cutoff (km) — at/under paints the pill's km green, over red.
  void setPickupNearKm(double km) =>
      _set(state.copyWith(pickupNearKm: km.clamp(0.5, 10.0)));

  /// Toggle a gig app on/off. The last remaining app can't be turned off —
  /// FoxyCo watching nothing is just confusing.
  void toggleApp(GigPlatform app) {
    final next = Set<GigPlatform>.from(state.watchedApps);
    if (next.contains(app)) {
      if (next.length == 1) return;
      next.remove(app);
    } else {
      next.add(app);
    }
    _set(state.copyWith(watchedApps: next));
  }

  void setRetentionDays(int days) => _set(state.copyWith(retentionDays: days));

  void setPillSize(PillSize size) => _set(state.copyWith(pillSize: size));

  void reset() => _set(FoxSettings.defaults);

  void setTrackOutcomes(bool on) => _set(state.copyWith(trackOutcomes: on));
}

final settingsProvider = NotifierProvider<SettingsController, FoxSettings>(
  SettingsController.new,
);

/// The $/km cut points alone — what the decision engine consumes.
final thresholdsProvider = Provider<Thresholds>(
  (ref) => ref.watch(settingsProvider).thresholds,
);
