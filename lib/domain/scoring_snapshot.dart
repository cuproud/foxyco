import 'app_currency.dart';
import 'distance_unit.dart';
import 'fox_settings.dart';
import 'rate_mode.dart';

/// The scoring inputs that materially explain one historical verdict.
///
/// This is intentionally smaller than [FoxSettings]. Preferences such as
/// overlay size, voice, and watched apps must never change the explanation of
/// an offer that was already scored.
class ScoringSnapshot {
  final RateMode rateMode;
  final double goodPerKm;
  final double badPerKm;
  final double goodPerHour;
  final double badPerHour;
  final bool minimumPayoutEnabled;
  final double minimumPayout;
  final double pickupNearKm;
  final DistanceUnit distanceUnit;
  final AppCurrency currency;

  const ScoringSnapshot({
    required this.rateMode,
    required this.goodPerKm,
    required this.badPerKm,
    required this.goodPerHour,
    required this.badPerHour,
    required this.minimumPayoutEnabled,
    required this.minimumPayout,
    required this.pickupNearKm,
    required this.distanceUnit,
    required this.currency,
  });

  factory ScoringSnapshot.fromSettings(FoxSettings s) => ScoringSnapshot(
    rateMode: s.rateMode,
    goodPerKm: s.thresholds.goodAtOrAbove,
    badPerKm: s.thresholds.badBelow,
    goodPerHour: s.hourThresholds.goodAtOrAbove,
    badPerHour: s.hourThresholds.badBelow,
    minimumPayoutEnabled: s.minimumPayoutEnabled,
    minimumPayout: s.minimumPayout,
    pickupNearKm: s.pickupNearKm,
    distanceUnit: s.distanceUnit,
    currency: s.currency,
  );

  Map<String, dynamic> toJson() => {
    'rateMode': rateMode.name,
    'goodPerKm': goodPerKm,
    'badPerKm': badPerKm,
    'goodPerHour': goodPerHour,
    'badPerHour': badPerHour,
    'minimumPayoutEnabled': minimumPayoutEnabled,
    'minimumPayout': minimumPayout,
    'pickupNearKm': pickupNearKm,
    'distanceUnit': distanceUnit.name,
    'currency': currency.name,
  };

  factory ScoringSnapshot.fromJson(Map<String, dynamic> j) => ScoringSnapshot(
    rateMode: RateMode.values.firstWhere(
      (v) => v.name == j['rateMode'],
      orElse: () => RateMode.perKm,
    ),
    goodPerKm: (j['goodPerKm'] as num?)?.toDouble() ?? 0,
    badPerKm: (j['badPerKm'] as num?)?.toDouble() ?? 0,
    goodPerHour: (j['goodPerHour'] as num?)?.toDouble() ?? 0,
    badPerHour: (j['badPerHour'] as num?)?.toDouble() ?? 0,
    minimumPayoutEnabled: j['minimumPayoutEnabled'] == true,
    minimumPayout: (j['minimumPayout'] as num?)?.toDouble() ?? 0,
    pickupNearKm: (j['pickupNearKm'] as num?)?.toDouble() ?? 0,
    distanceUnit: DistanceUnit.fromName(j['distanceUnit'] as String?),
    currency: AppCurrency.fromName(j['currency'] as String?),
  );
}
