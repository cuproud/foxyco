/// Which rate the verdict engine scores an offer by. The driver picks one in
/// Settings; thresholds are kept per-mode ($/km and $/hr are different scales)
/// so switching back and forth never mangles the cut points.
enum RateMode {
  /// Dollars per kilometre over the whole job (pickup + trip). MVP default.
  perKm,

  /// Dollars per hour over the whole job — needs parsed minutes; offers
  /// without time data fall back to $/km scoring (fail safe, never a blind
  /// verdict).
  perHour;

  String get label => switch (this) {
    RateMode.perKm => r'$/km',
    RateMode.perHour => r'$/hr',
  };
}
