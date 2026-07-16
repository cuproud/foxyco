import 'fox_settings.dart';
import 'offer.dart';
import 'rate_mode.dart';
import 'thresholds.dart';
import 'verdict.dart';

/// The whole brain for MVP: map a rate ($/km or $/hr) to a [Verdict] against
/// the user's [Thresholds]. Pure Dart, no side effects — 100% branch-covered
/// by tests (docs/ARCHITECTURE §testing). The overlay isolate calls this on
/// every offer.
///
/// Boundaries are deliberate: `goodAtOrAbove` is inclusive, `badBelow` is
/// exclusive, so the OK band is `[badBelow, goodAtOrAbove)`.
class DecisionEngine {
  const DecisionEngine();

  Verdict evaluate(double rate, Thresholds t) {
    if (rate >= t.goodAtOrAbove) return Verdict.good;
    if (rate < t.badBelow) return Verdict.bad;
    return Verdict.ok;
  }

  /// Score a parsed [Offer] end-to-end. Convenience over [evaluate] for the M3
  /// pipeline (parser → engine → overlay); the $/km math lives on the model so
  /// this stays a thin delegate. A zero-km offer yields `pricePerKm == 0`, which
  /// falls into BAD — an offer with no distance is not one to take.
  Verdict evaluateOffer(Offer offer, Thresholds t) =>
      evaluate(offer.pricePerKm, t);

  /// Score honoring the driver's [FoxSettings.rateMode]. In $/hr mode an offer
  /// with NO parsed minutes falls back to $/km against the $/km cut points —
  /// fail safe: a real rate on the wrong scale beats scoring `0/hr` as BAD on
  /// a possibly great offer (and beats showing nothing; km data is always
  /// there, minutes sometimes aren't — e.g. some Uber cards).
  Verdict scoreOffer(Offer offer, FoxSettings s) {
    if (s.rateMode == RateMode.perHour && offer.totalMinutes > 0) {
      return evaluate(offer.pricePerHour, s.hourThresholds);
    }
    return evaluate(offer.pricePerKm, s.thresholds);
  }
}
