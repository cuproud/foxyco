import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_skin.dart';
import '../../domain/app_currency.dart';
import '../../domain/distance_unit.dart';
import '../../domain/fox_settings.dart';
import '../../domain/money_font.dart';
import '../../domain/overlay_payload.dart' show PillSize;
import '../../domain/platform.dart';
import '../../domain/rate_mode.dart';
import '../../domain/thresholds.dart';
import '../../domain/verdict.dart';
import '../../services/ocr/ocr_capture.dart';
import '../../services/verdict_voice.dart';

/// Holds every driver-tunable knob ([FoxSettings]) and persists it as one
/// SharedPreferences JSON blob. The overlay isolate gets the values it needs
/// via the shareData payload, so this stays the single source of truth.
///
/// Off-device (widget tests) the prefs channel isn't registered; loads fail
/// soft to defaults and saves are best-effort, so tests see [FoxSettings.defaults].
class SettingsController extends Notifier<FoxSettings> {
  static const _prefsKey = 'foxyco.settings.v1';
  final Completer<void> _ready = Completer<void>();
  final List<FoxSettings Function(FoxSettings)> _pending = [];
  bool _hydrated = false;

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @override
  FoxSettings build() {
    _load();
    return FoxSettings.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await preferences();
      final raw = prefs.getString(_prefsKey);
      var loaded = raw == null
          ? await _storeDefaults()
          : FoxSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      for (final change in _pending) {
        loaded = change(loaded);
      }
      if (ref.mounted) state = loaded;
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo settings load skipped: $e');
    } finally {
      _hydrated = true;
      _pending.clear();
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<FoxSettings> _storeDefaults() async {
    final country = await ref.read(playStoreCountryProvider)();
    final currency = AppCurrency.fromCountryCode(country);
    return FoxSettings.defaults.copyWith(
      currency: currency,
      distanceUnit: _distanceFor(currency),
    );
  }

  static DistanceUnit _distanceFor(AppCurrency currency) =>
      currency == AppCurrency.usd
      ? DistanceUnit.miles
      : DistanceUnit.kilometres;

  Future<void> _save() async {
    try {
      await _ready.future;
      if (!ref.mounted) return;
      final prefs = await preferences();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo settings save skipped: $e');
    }
  }

  void _change(FoxSettings Function(FoxSettings) change) {
    final previous = state;
    final next = change(previous);
    if (!_hydrated) _pending.add(change);
    state = next;
    if (previous.ocrEnabled && !next.ocrEnabled) {
      unawaited(ref.read(ocrCaptureProvider).stop());
    }
    if (previous.voiceVerdictEnabled && !next.voiceVerdictEnabled) {
      unawaited(ref.read(verdictVoiceProvider).stop());
    }
    unawaited(_save());
  }

  /// GOOD cut for the ACTIVE rate mode. Clamped so it can never dip below the
  /// BAD cut (keeps the band coherent — see [Thresholds.isValid]); the slider
  /// also enforces this.
  void setGood(double value) {
    _change((current) {
      final t = current.activeThresholds;
      final clamped = value < t.badBelow ? t.badBelow : value;
      return _withActive(current, t.copyWith(goodAtOrAbove: clamped));
    });
  }

  /// BAD cut for the ACTIVE rate mode. Clamped so it can never rise above the
  /// GOOD cut.
  void setBad(double value) {
    _change((current) {
      final t = current.activeThresholds;
      final clamped = value > t.goodAtOrAbove ? t.goodAtOrAbove : value;
      return _withActive(current, t.copyWith(badBelow: clamped));
    });
  }

  /// Write [next] into whichever thresholds pair the active mode uses.
  FoxSettings _withActive(FoxSettings current, Thresholds next) =>
      switch (current.rateMode) {
        RateMode.perKm => current.copyWith(thresholds: next),
        RateMode.perHour => current.copyWith(hourThresholds: next),
      };

  /// Apply a whole cut-point pair at once (threshold presets — onboarding and
  /// the Settings preset chips). Ignores invalid pairs.
  void applyPreset(Thresholds t) {
    if (t.isValid) _change((current) => _withActive(current, t));
  }

  /// Score by $/km or $/hr. Each mode keeps its own cut points.
  void setRateMode(RateMode mode) =>
      _change((current) => current.copyWith(rateMode: mode));

  void setMinimumPayoutEnabled(bool enabled) =>
      _change((current) => current.copyWith(minimumPayoutEnabled: enabled));

  void setMinimumPayout(double amount) => _change(
    (current) => current.copyWith(minimumPayout: amount.clamp(0, 500)),
  );

  void setMinimumPayoutVerdict(Verdict verdict) {
    if (verdict == Verdict.unknown) return;
    _change((current) => current.copyWith(minimumPayoutVerdict: verdict));
  }

  /// Pickup-near cutoff (km) — at/under paints the pill's km green, over red.
  void setPickupNearKm(double km) =>
      _change((current) => current.copyWith(pickupNearKm: km.clamp(0.5, 10.0)));

  /// Toggle a gig app on/off. The last remaining app can't be turned off —
  /// FoxyCo watching nothing is just confusing.
  void toggleApp(GigPlatform app) {
    _change((current) {
      final next = Set<GigPlatform>.from(current.watchedApps);
      if (next.contains(app)) {
        if (next.length == 1) return current;
        next.remove(app);
      } else {
        next.add(app);
      }
      return current.copyWith(watchedApps: next);
    });
  }

  void setRetentionDays(int days) =>
      _change((current) => current.copyWith(retentionDays: days));

  void setPillSize(PillSize size) =>
      _change((current) => current.copyWith(pillSize: size));

  void reset() => _change((_) => FoxSettings.defaults);

  void setTrackOutcomes(bool on) =>
      _change((current) => current.copyWith(trackOutcomes: on));

  void setVoiceVerdictEnabled(bool on) =>
      _change((current) => current.copyWith(voiceVerdictEnabled: on));

  void setAnnounceGoodOffers(bool on) =>
      _change((current) => current.copyWith(announceGoodOffers: on));

  void setAnnounceOkOffers(bool on) =>
      _change((current) => current.copyWith(announceOkOffers: on));

  void setGoodVoiceMinimumPayout(double amount) => _change(
    (current) => current.copyWith(goodVoiceMinimumPayout: amount.clamp(0, 500)),
  );

  void setOkVoiceMinimumPayout(double amount) => _change(
    (current) => current.copyWith(okVoiceMinimumPayout: amount.clamp(0, 500)),
  );

  void setVoiceCooldownSeconds(int seconds) => _change(
    (current) => current.copyWith(voiceCooldownSeconds: seconds.clamp(5, 120)),
  );

  void setOcrEnabled(bool on) => _change(
    (current) => current.copyWith(
      ocrEnabled: on,
      ocrTestMode: on ? current.ocrTestMode : false,
    ),
  );

  void setOcrTestMode(bool on) => _change(
    (current) =>
        current.copyWith(ocrTestMode: kDebugMode && current.ocrEnabled && on),
  );

  void setMoneyFont(MoneyFont font) =>
      _change((current) => current.copyWith(moneyFont: font));

  void setSkin(AppSkin skin) =>
      _change((current) => current.copyWith(skin: skin));

  void setDistanceUnit(DistanceUnit unit) =>
      _change((current) => current.copyWith(distanceUnit: unit));

  void setCurrency(AppCurrency currency) => _change(
    (current) => current.copyWith(
      currency: currency,
      distanceUnit: _distanceFor(currency),
    ),
  );

  /// UI thresholds are expressed in the selected unit; storage/scoring stays
  /// canonical in dollars per kilometre.
  void setDisplayedGood(double value) => _change((current) {
    final canonical = current.distanceUnit.rateToPerKm(value);
    final t = current.activeThresholds;
    final clamped = canonical < t.badBelow ? t.badBelow : canonical;
    return _withActive(current, t.copyWith(goodAtOrAbove: clamped));
  });

  void setDisplayedBad(double value) => _change((current) {
    final canonical = current.distanceUnit.rateToPerKm(value);
    final t = current.activeThresholds;
    final clamped = canonical > t.goodAtOrAbove ? t.goodAtOrAbove : canonical;
    return _withActive(current, t.copyWith(badBelow: clamped));
  });

  void setDisplayedPickupNear(double value) => _change(
    (current) => current.copyWith(
      pickupNearKm: current.distanceUnit.distanceToKm(value).clamp(0.5, 10.0),
    ),
  );
}

final settingsProvider = NotifierProvider<SettingsController, FoxSettings>(
  SettingsController.new,
);

/// Google Play's storefront country for first-run defaults. Tests and
/// non-Android builds never initialize the billing plugin.
final playStoreCountryProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    if (!Platform.isAndroid) return null;
    try {
      return await InAppPurchase.instance.countryCode();
    } catch (_) {
      return null;
    }
  };
});

/// The $/km cut points alone — what the decision engine consumes.
final thresholdsProvider = Provider<Thresholds>(
  (ref) => ref.watch(settingsProvider).thresholds,
);
