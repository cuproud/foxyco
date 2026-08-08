import 'app_skin.dart';
import 'app_currency.dart';
import 'distance_unit.dart';
import 'money_font.dart';
import 'overlay_payload.dart' show PillSize;
import 'platform.dart';
import 'rate_mode.dart';
import 'thresholds.dart';

/// Everything the driver can tune, in one persisted object.
///
/// Pure Dart (no Flutter/plugins). [toJson]/[fromJson] are the whole storage
/// format — a single SharedPreferences string. Adding a field: give it a
/// default in [defaults] and a null-safe read in [fromJson] so old saved blobs
/// still load.
class FoxSettings {
  /// $/km cut points → GOOD/OK/BAD.
  final Thresholds thresholds;

  /// $/hr cut points, used when [rateMode] is [RateMode.perHour]. Kept
  /// separate from [thresholds] — the scales differ by ~20×, so sharing one
  /// pair would mangle the band on every mode switch.
  final Thresholds hourThresholds;

  /// Which rate the verdict engine scores by ($/km or $/hr).
  final RateMode rateMode;

  /// Pickup distance at or under this (km) is "near" — the pill paints the trip
  /// km green; over it, red. The driver's dead-mileage guard.
  final double pickupNearKm;

  /// Which gig apps FoxyCo reads offers from.
  final Set<GigPlatform> watchedApps;

  /// Keep logged offers this many days; [keepForever] disables purging.
  final int retentionDays;

  /// Floating pill size.
  final PillSize pillSize;

  /// Infer taken/missed outcomes from where the app lands after an offer card
  /// leaves (read-only heuristic). Off = every offer logs as unknown.
  final bool trackOutcomes;

  /// Typeface for the big money numbers, picked in Settings → Appearance.
  final MoneyFont moneyFont;

  /// Light or dark palette, picked in Settings → Appearance.
  final AppSkin skin;

  /// Display preferences only. Offers stay stored in kilometres and in the
  /// numeric currency reported by the gig app; no FX conversion is attempted.
  final DistanceUnit distanceUnit;
  final AppCurrency currency;

  const FoxSettings({
    required this.thresholds,
    required this.hourThresholds,
    required this.rateMode,
    required this.pickupNearKm,
    required this.watchedApps,
    required this.retentionDays,
    required this.pillSize,
    required this.trackOutcomes,
    this.moneyFont = MoneyFont.inter,
    this.skin = AppSkin.light,
    this.distanceUnit = DistanceUnit.kilometres,
    this.currency = AppCurrency.cad,
  });

  static const keepForever = 9999;

  /// $/hr seeds: GOOD ≥ $30/hr, BAD < $20/hr — roughly where full-time
  /// rideshare "worth it / not worth it" talk lands; driver-tunable anyway.
  static const defaultHourThresholds = Thresholds(
    goodAtOrAbove: 30,
    badBelow: 20,
  );

  static final defaults = FoxSettings(
    thresholds: Thresholds.defaults,
    hourThresholds: defaultHourThresholds,
    rateMode: RateMode.perKm,
    pickupNearKm: 2.0,
    watchedApps: {GigPlatform.uber, GigPlatform.hopp, GigPlatform.lyft},
    retentionDays: 30,
    pillSize: PillSize.small,
    trackOutcomes: true,
    moneyFont: MoneyFont.inter,
    skin: AppSkin.light,
    distanceUnit: DistanceUnit.kilometres,
    currency: AppCurrency.cad,
  );

  bool watches(GigPlatform p) => watchedApps.contains(p);

  /// The cut points for the ACTIVE [rateMode] — what the engine scores with.
  Thresholds get activeThresholds => switch (rateMode) {
    RateMode.perKm => thresholds,
    RateMode.perHour => hourThresholds,
  };

  FoxSettings copyWith({
    Thresholds? thresholds,
    Thresholds? hourThresholds,
    RateMode? rateMode,
    double? pickupNearKm,
    Set<GigPlatform>? watchedApps,
    int? retentionDays,
    PillSize? pillSize,
    bool? trackOutcomes,
    MoneyFont? moneyFont,
    AppSkin? skin,
    DistanceUnit? distanceUnit,
    AppCurrency? currency,
  }) => FoxSettings(
    thresholds: thresholds ?? this.thresholds,
    hourThresholds: hourThresholds ?? this.hourThresholds,
    rateMode: rateMode ?? this.rateMode,
    pickupNearKm: pickupNearKm ?? this.pickupNearKm,
    watchedApps: watchedApps ?? this.watchedApps,
    retentionDays: retentionDays ?? this.retentionDays,
    pillSize: pillSize ?? this.pillSize,
    trackOutcomes: trackOutcomes ?? this.trackOutcomes,
    moneyFont: moneyFont ?? this.moneyFont,
    skin: skin ?? this.skin,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    currency: currency ?? this.currency,
  );

  Map<String, dynamic> toJson() => {
    'good': thresholds.goodAtOrAbove,
    'bad': thresholds.badBelow,
    'hourGood': hourThresholds.goodAtOrAbove,
    'hourBad': hourThresholds.badBelow,
    'rateMode': rateMode.name,
    'pickupNearKm': pickupNearKm,
    'watchedApps': watchedApps.map((p) => p.name).toList(),
    'retentionDays': retentionDays,
    'pillSize': pillSize.name,
    'trackOutcomes': trackOutcomes,
    'moneyFont': moneyFont.name,
    'skin': skin.name,
    'distanceUnit': distanceUnit.name,
    'currency': currency.name,
  };

  factory FoxSettings.fromJson(Map<String, dynamic> j) {
    final d = defaults;
    double number(String key, double fallback, double min, double max) =>
        ((j[key] as num?)?.toDouble() ?? fallback)
            .clamp(min, max)
            .toDouble();
    final good = number('good', d.thresholds.goodAtOrAbove, 0.5, 3.0);
    final bad = number('bad', d.thresholds.badBelow, 0.5, 3.0);
    final hourGood = number('hourGood', d.hourThresholds.goodAtOrAbove, 10, 60);
    final hourBad = number('hourBad', d.hourThresholds.badBelow, 10, 60);
    final retention = (j['retentionDays'] as num?)?.toInt();
    final apps = (j['watchedApps'] as List<dynamic>?)
        ?.map((n) => GigPlatform.values.where((p) => p.name == n))
        .expand((e) => e)
        .toSet();
    return FoxSettings(
      thresholds: good >= bad
          ? Thresholds(goodAtOrAbove: good, badBelow: bad)
          : d.thresholds,
      hourThresholds: hourGood >= hourBad
          ? Thresholds(goodAtOrAbove: hourGood, badBelow: hourBad)
          : d.hourThresholds,
      rateMode:
          RateMode.values.where((m) => m.name == j['rateMode']).firstOrNull ??
          d.rateMode,
      pickupNearKm: number('pickupNearKm', d.pickupNearKm, 0.5, 10),
      watchedApps: (apps == null || apps.isEmpty) ? d.watchedApps : apps,
      retentionDays: const [7, 30, 90, keepForever].contains(retention)
          ? retention!
          : d.retentionDays,
      pillSize:
          PillSize.values.where((s) => s.name == j['pillSize']).firstOrNull ??
          d.pillSize,
      trackOutcomes: (j['trackOutcomes'] as bool?) ?? d.trackOutcomes,
      moneyFont: MoneyFont.fromName(j['moneyFont'] as String?),
      skin: AppSkin.fromName(j['skin'] as String?),
      distanceUnit: DistanceUnit.fromName(j['distanceUnit'] as String?),
      currency: AppCurrency.fromName(j['currency'] as String?),
    );
  }
}
