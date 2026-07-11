import 'thresholds.dart';
import 'verdict.dart';

/// The whole brain for MVP: map a $/km value to a [Verdict] against the user's
/// [Thresholds]. Pure Dart, no side effects — 100% branch-covered by tests
/// (docs/ARCHITECTURE §testing). The overlay isolate calls this on every offer.
///
/// Boundaries are deliberate: `goodAtOrAbove` is inclusive, `badBelow` is
/// exclusive, so the OK band is `[badBelow, goodAtOrAbove)`.
class DecisionEngine {
  const DecisionEngine();

  Verdict evaluate(double pricePerKm, Thresholds t) {
    if (pricePerKm >= t.goodAtOrAbove) return Verdict.good;
    if (pricePerKm < t.badBelow) return Verdict.bad;
    return Verdict.ok;
  }
}
