/// Driver-facing distance system. All persisted offer distances remain in
/// kilometres; conversion happens only at input/display boundaries.
enum DistanceUnit {
  kilometres,
  miles;

  static const kilometresPerMile = 1.609344;

  String get label => switch (this) {
    kilometres => 'Kilometres',
    miles => 'Miles',
  };

  String get shortLabel => switch (this) {
    kilometres => 'km',
    miles => 'mi',
  };

  double distanceFromKm(double km) => switch (this) {
    kilometres => km,
    miles => km / kilometresPerMile,
  };

  double distanceToKm(double value) => switch (this) {
    kilometres => value,
    miles => value * kilometresPerMile,
  };

  /// Converts a canonical dollars-per-km rate for display.
  double rateFromPerKm(double perKm) => switch (this) {
    kilometres => perKm,
    miles => perKm * kilometresPerMile,
  };

  /// Converts a driver-entered rate back to canonical dollars per kilometre.
  double rateToPerKm(double value) => switch (this) {
    kilometres => value,
    miles => value / kilometresPerMile,
  };

  static DistanceUnit fromName(String? name) =>
      values.firstWhere((unit) => unit.name == name, orElse: () => kilometres);
}
