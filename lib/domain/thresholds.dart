/// The two $/km cut points that turn a raw offer into a verdict. Pure Dart.
///
/// A driver sets these once in Settings and they drive every call the overlay
/// makes. Kept deliberately tiny — this is the whole tunable surface for MVP.
class Thresholds {
  final double goodAtOrAbove; // $/km — at or above this ⇒ GOOD
  final double badBelow; // $/km — below this ⇒ BAD; between the two ⇒ OK

  const Thresholds({required this.goodAtOrAbove, required this.badBelow});

  /// Sensible starting point for a new driver (docs/UI_DESIGN onboarding).
  static const defaults = Thresholds(goodAtOrAbove: 1.5, badBelow: 1.0);

  /// True when the band is coherent: GOOD cut must sit at or above the BAD cut.
  /// A UI that lets the user cross them should clamp before constructing.
  bool get isValid => goodAtOrAbove >= badBelow;

  Thresholds copyWith({double? goodAtOrAbove, double? badBelow}) => Thresholds(
    goodAtOrAbove: goodAtOrAbove ?? this.goodAtOrAbove,
    badBelow: badBelow ?? this.badBelow,
  );

  @override
  bool operator ==(Object other) =>
      other is Thresholds &&
      other.goodAtOrAbove == goodAtOrAbove &&
      other.badBelow == badBelow;

  @override
  int get hashCode => Object.hash(goodAtOrAbove, badBelow);
}
