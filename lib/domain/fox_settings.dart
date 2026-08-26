import 'app_skin.dart';
import 'app_text_size.dart';
import 'app_currency.dart';
import 'bubble_style.dart';
import 'distance_unit.dart';
import 'money_font.dart';
import 'overlay_payload.dart' show PillSize;
import 'platform.dart';
import 'rate_mode.dart';
import 'thresholds.dart';
import 'verdict.dart';

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

  /// Optional payout floor applied before rate scoring. Existing installs keep
  /// it disabled until the driver explicitly opts in.
  final bool minimumPayoutEnabled;
  final double minimumPayout;

  /// Legacy persisted field kept so existing settings blobs round-trip.
  /// Minimum payout failures are always BAD; this value is no longer read.
  final Verdict minimumPayoutVerdict;

  /// Pickup distance at or under this (km) makes the pill's GPS target green;
  /// over it, red. This is informational and does not change the verdict.
  final double pickupNearKm;

  /// Delivery apps keep independent economics from rideshare.
  final Thresholds deliveryThresholds;
  final Thresholds deliveryHourThresholds;
  final RateMode deliveryRateMode;
  final bool deliveryMinimumPayoutEnabled;
  final double deliveryMinimumPayout;

  /// Which gig apps FoxyCo reads offers from.
  final Set<GigPlatform> watchedApps;

  /// Keep logged offers this many days; [keepForever] disables purging.
  final int retentionDays;

  /// Floating pill size.
  final PillSize pillSize;

  /// Main-app typography only. The driving overlay remains controlled by
  /// [pillSize] so app text preferences cannot break the floating pill.
  final AppTextSize appTextSize;

  /// Artwork shown by the resting floating overlay bubble.
  final BubbleStyle bubbleStyle;

  /// Infer taken/missed outcomes from where the app lands after an offer card
  /// leaves (read-only heuristic). Off = every offer logs as unknown.
  final bool trackOutcomes;

  /// Master switch for verdict voice alerts.
  final bool voiceVerdictEnabled;

  /// Speak a short alert when a newly logged offer scores GOOD.
  final bool announceGoodOffers;
  final bool announceOkOffers;

  /// Legacy payout fields retained for settings migration compatibility. They
  /// are no longer read by verdict scoring or voice announcements.
  final double goodVoiceMinimumPayout;
  final double okVoiceMinimumPayout;
  final int voiceCooldownSeconds;

  /// Opt-in, on-device screenshot OCR fallback for Uber. Accessibility remains
  /// primary for every platform.
  final bool ocrEnabled;

  /// Debug-session override that bypasses Accessibility parsing so the OCR
  /// fallback can be exercised with a fully readable card. Never persisted.
  final bool ocrTestMode;

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
    this.minimumPayoutEnabled = false,
    this.minimumPayout = 5,
    this.minimumPayoutVerdict = Verdict.bad,
    required this.pickupNearKm,
    this.deliveryThresholds = Thresholds.defaults,
    this.deliveryHourThresholds = defaultHourThresholds,
    this.deliveryRateMode = RateMode.perKm,
    this.deliveryMinimumPayoutEnabled = false,
    this.deliveryMinimumPayout = 7,
    required this.watchedApps,
    required this.retentionDays,
    required this.pillSize,
    this.appTextSize = AppTextSize.medium,
    this.bubbleStyle = BubbleStyle.coolFox,
    required this.trackOutcomes,
    this.voiceVerdictEnabled = true,
    this.announceGoodOffers = true,
    this.announceOkOffers = false,
    this.goodVoiceMinimumPayout = 30,
    this.okVoiceMinimumPayout = 20,
    this.voiceCooldownSeconds = 15,
    this.ocrEnabled = false,
    this.ocrTestMode = false,
    this.moneyFont = MoneyFont.inter,
    this.skin = AppSkin.light,
    this.distanceUnit = DistanceUnit.kilometres,
    this.currency = AppCurrency.cad,
  });

  static const keepForever = 9999;
  static const maxWatchedApps = 3;

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
    minimumPayoutEnabled: false,
    minimumPayout: 5,
    minimumPayoutVerdict: Verdict.bad,
    pickupNearKm: 2.0,
    deliveryThresholds: Thresholds.defaults,
    deliveryHourThresholds: defaultHourThresholds,
    deliveryRateMode: RateMode.perKm,
    deliveryMinimumPayoutEnabled: false,
    deliveryMinimumPayout: 7,
    watchedApps: {},
    retentionDays: 30,
    pillSize: PillSize.small,
    appTextSize: AppTextSize.medium,
    bubbleStyle: BubbleStyle.coolFox,
    trackOutcomes: true,
    voiceVerdictEnabled: true,
    announceGoodOffers: true,
    announceOkOffers: false,
    goodVoiceMinimumPayout: 30,
    okVoiceMinimumPayout: 20,
    voiceCooldownSeconds: 15,
    ocrEnabled: false,
    ocrTestMode: false,
    moneyFont: MoneyFont.inter,
    skin: AppSkin.light,
    distanceUnit: DistanceUnit.kilometres,
    currency: AppCurrency.cad,
  );

  bool watches(GigPlatform p) => watchedApps.contains(p);
  bool get watchesDelivery => watchedApps.any((app) => app.isDelivery);
  bool get watchesDeliveryRules => watches(GigPlatform.uber) || watchesDelivery;

  RateMode rateModeFor(GigPlatform platform) =>
      platform.isDelivery ? deliveryRateMode : rateMode;
  Thresholds distanceThresholdsFor(GigPlatform platform) =>
      platform.isDelivery ? deliveryThresholds : thresholds;
  Thresholds hourThresholdsFor(GigPlatform platform) =>
      platform.isDelivery ? deliveryHourThresholds : hourThresholds;
  bool minimumPayoutEnabledFor(GigPlatform platform) =>
      platform.isDelivery ? deliveryMinimumPayoutEnabled : minimumPayoutEnabled;
  double minimumPayoutFor(GigPlatform platform) =>
      platform.isDelivery ? deliveryMinimumPayout : minimumPayout;

  /// The cut points for the ACTIVE [rateMode] — what the engine scores with.
  Thresholds get activeThresholds => switch (rateMode) {
    RateMode.perKm => thresholds,
    RateMode.perHour => hourThresholds,
  };

  FoxSettings copyWith({
    Thresholds? thresholds,
    Thresholds? hourThresholds,
    RateMode? rateMode,
    bool? minimumPayoutEnabled,
    double? minimumPayout,
    Verdict? minimumPayoutVerdict,
    double? pickupNearKm,
    Thresholds? deliveryThresholds,
    Thresholds? deliveryHourThresholds,
    RateMode? deliveryRateMode,
    bool? deliveryMinimumPayoutEnabled,
    double? deliveryMinimumPayout,
    Set<GigPlatform>? watchedApps,
    int? retentionDays,
    PillSize? pillSize,
    AppTextSize? appTextSize,
    BubbleStyle? bubbleStyle,
    bool? trackOutcomes,
    bool? voiceVerdictEnabled,
    bool? announceGoodOffers,
    bool? announceOkOffers,
    double? goodVoiceMinimumPayout,
    double? okVoiceMinimumPayout,
    int? voiceCooldownSeconds,
    bool? ocrEnabled,
    bool? ocrTestMode,
    MoneyFont? moneyFont,
    AppSkin? skin,
    DistanceUnit? distanceUnit,
    AppCurrency? currency,
  }) => FoxSettings(
    thresholds: thresholds ?? this.thresholds,
    hourThresholds: hourThresholds ?? this.hourThresholds,
    rateMode: rateMode ?? this.rateMode,
    minimumPayoutEnabled: minimumPayoutEnabled ?? this.minimumPayoutEnabled,
    minimumPayout: minimumPayout ?? this.minimumPayout,
    minimumPayoutVerdict: minimumPayoutVerdict ?? this.minimumPayoutVerdict,
    pickupNearKm: pickupNearKm ?? this.pickupNearKm,
    deliveryThresholds: deliveryThresholds ?? this.deliveryThresholds,
    deliveryHourThresholds:
        deliveryHourThresholds ?? this.deliveryHourThresholds,
    deliveryRateMode: deliveryRateMode ?? this.deliveryRateMode,
    deliveryMinimumPayoutEnabled:
        deliveryMinimumPayoutEnabled ?? this.deliveryMinimumPayoutEnabled,
    deliveryMinimumPayout: deliveryMinimumPayout ?? this.deliveryMinimumPayout,
    watchedApps: watchedApps ?? this.watchedApps,
    retentionDays: retentionDays ?? this.retentionDays,
    pillSize: pillSize ?? this.pillSize,
    appTextSize: appTextSize ?? this.appTextSize,
    bubbleStyle: bubbleStyle ?? this.bubbleStyle,
    trackOutcomes: trackOutcomes ?? this.trackOutcomes,
    voiceVerdictEnabled: voiceVerdictEnabled ?? this.voiceVerdictEnabled,
    announceGoodOffers: announceGoodOffers ?? this.announceGoodOffers,
    announceOkOffers: announceOkOffers ?? this.announceOkOffers,
    goodVoiceMinimumPayout:
        goodVoiceMinimumPayout ?? this.goodVoiceMinimumPayout,
    okVoiceMinimumPayout: okVoiceMinimumPayout ?? this.okVoiceMinimumPayout,
    voiceCooldownSeconds: voiceCooldownSeconds ?? this.voiceCooldownSeconds,
    ocrEnabled: ocrEnabled ?? this.ocrEnabled,
    ocrTestMode: ocrTestMode ?? this.ocrTestMode,
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
    'minimumPayoutEnabled': minimumPayoutEnabled,
    'minimumPayout': minimumPayout,
    'minimumPayoutVerdict': minimumPayoutVerdict.name,
    'pickupNearKm': pickupNearKm,
    'deliveryGood': deliveryThresholds.goodAtOrAbove,
    'deliveryBad': deliveryThresholds.badBelow,
    'deliveryHourGood': deliveryHourThresholds.goodAtOrAbove,
    'deliveryHourBad': deliveryHourThresholds.badBelow,
    'deliveryRateMode': deliveryRateMode.name,
    'deliveryMinimumPayoutEnabled': deliveryMinimumPayoutEnabled,
    'deliveryMinimumPayout': deliveryMinimumPayout,
    'watchedApps': watchedApps.map((p) => p.name).toList(),
    'retentionDays': retentionDays,
    'pillSize': pillSize.name,
    'appTextSize': appTextSize.name,
    'bubbleStyle': bubbleStyle.id,
    'trackOutcomes': trackOutcomes,
    'voiceVerdictEnabled': voiceVerdictEnabled,
    'announceGoodOffers': announceGoodOffers,
    'announceOkOffers': announceOkOffers,
    'goodVoiceMinimumPayout': goodVoiceMinimumPayout,
    'okVoiceMinimumPayout': okVoiceMinimumPayout,
    'voiceCooldownSeconds': voiceCooldownSeconds,
    'ocrEnabled': ocrEnabled,
    'moneyFont': moneyFont.name,
    'skin': skin.name,
    'distanceUnit': distanceUnit.name,
    'currency': currency.name,
  };

  factory FoxSettings.fromJson(Map<String, dynamic> j) {
    final d = defaults;
    double number(String key, double fallback, double min, double max) =>
        ((j[key] as num?)?.toDouble() ?? fallback).clamp(min, max).toDouble();
    final good = number('good', d.thresholds.goodAtOrAbove, 0.5, 3.0);
    final bad = number('bad', d.thresholds.badBelow, 0.5, 3.0);
    final hourGood = number('hourGood', d.hourThresholds.goodAtOrAbove, 10, 60);
    final hourBad = number('hourBad', d.hourThresholds.badBelow, 10, 60);
    final deliveryGood = number(
      'deliveryGood',
      d.deliveryThresholds.goodAtOrAbove,
      0.5,
      3.0,
    );
    final deliveryBad = number(
      'deliveryBad',
      d.deliveryThresholds.badBelow,
      0.5,
      3.0,
    );
    final deliveryHourGood = number(
      'deliveryHourGood',
      d.deliveryHourThresholds.goodAtOrAbove,
      10,
      60,
    );
    final deliveryHourBad = number(
      'deliveryHourBad',
      d.deliveryHourThresholds.badBelow,
      10,
      60,
    );
    final retention = (j['retentionDays'] as num?)?.toInt();
    final apps = (j['watchedApps'] as List<dynamic>?)
        ?.map((n) => GigPlatform.values.where((p) => p.name == n))
        .expand((e) => e)
        .toSet();
    final watchedApps = (apps ?? d.watchedApps).take(maxWatchedApps).toSet();
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
      minimumPayoutEnabled:
          (j['minimumPayoutEnabled'] as bool?) ?? d.minimumPayoutEnabled,
      minimumPayout: number('minimumPayout', d.minimumPayout, 0, 500),
      minimumPayoutVerdict:
          Verdict.values
              .where((verdict) => verdict != Verdict.unknown)
              .where((verdict) => verdict.name == j['minimumPayoutVerdict'])
              .firstOrNull ??
          d.minimumPayoutVerdict,
      pickupNearKm: number('pickupNearKm', d.pickupNearKm, 0.5, 10),
      deliveryThresholds: deliveryGood >= deliveryBad
          ? Thresholds(goodAtOrAbove: deliveryGood, badBelow: deliveryBad)
          : d.deliveryThresholds,
      deliveryHourThresholds: deliveryHourGood >= deliveryHourBad
          ? Thresholds(
              goodAtOrAbove: deliveryHourGood,
              badBelow: deliveryHourBad,
            )
          : d.deliveryHourThresholds,
      deliveryRateMode:
          RateMode.values
              .where((m) => m.name == j['deliveryRateMode'])
              .firstOrNull ??
          d.deliveryRateMode,
      deliveryMinimumPayoutEnabled:
          (j['deliveryMinimumPayoutEnabled'] as bool?) ??
          d.deliveryMinimumPayoutEnabled,
      deliveryMinimumPayout: number(
        'deliveryMinimumPayout',
        d.deliveryMinimumPayout,
        0,
        500,
      ),
      watchedApps: watchedApps,
      retentionDays: const [7, 30, 90, keepForever].contains(retention)
          ? retention!
          : d.retentionDays,
      pillSize:
          PillSize.values.where((s) => s.name == j['pillSize']).firstOrNull ??
          d.pillSize,
      appTextSize: AppTextSize.fromName(j['appTextSize'] as String?),
      bubbleStyle: BubbleStyle.fromId(
        j['bubbleStyle'] is String ? j['bubbleStyle'] as String : null,
      ),
      trackOutcomes: (j['trackOutcomes'] as bool?) ?? d.trackOutcomes,
      voiceVerdictEnabled:
          (j['voiceVerdictEnabled'] as bool?) ??
          (((j['announceGoodOffers'] as bool?) ?? d.announceGoodOffers) ||
              ((j['announceOkOffers'] as bool?) ?? d.announceOkOffers)),
      announceGoodOffers:
          (j['announceGoodOffers'] as bool?) ?? d.announceGoodOffers,
      announceOkOffers: (j['announceOkOffers'] as bool?) ?? d.announceOkOffers,
      goodVoiceMinimumPayout: number(
        'goodVoiceMinimumPayout',
        d.goodVoiceMinimumPayout,
        0,
        500,
      ),
      okVoiceMinimumPayout: number(
        'okVoiceMinimumPayout',
        d.okVoiceMinimumPayout,
        0,
        500,
      ),
      voiceCooldownSeconds:
          ((j['voiceCooldownSeconds'] as num?)?.toInt() ??
                  d.voiceCooldownSeconds)
              .clamp(5, 120),
      ocrEnabled: watchedApps.contains(GigPlatform.uber),
      moneyFont: MoneyFont.fromName(j['moneyFont'] as String?),
      skin: AppSkin.fromName(j['skin'] as String?),
      distanceUnit: DistanceUnit.fromName(j['distanceUnit'] as String?),
      currency: AppCurrency.fromName(j['currency'] as String?),
    );
  }
}
