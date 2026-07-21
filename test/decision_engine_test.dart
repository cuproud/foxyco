import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/decision_engine.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/domain/offer.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/rate_mode.dart';
import 'package:foxyco/domain/thresholds.dart';
import 'package:foxyco/domain/verdict.dart';

void main() {
  const engine = DecisionEngine();
  const t = Thresholds(goodAtOrAbove: 1.5, badBelow: 1.0);

  group('DecisionEngine.evaluate — every branch', () {
    test('at or above the GOOD cut ⇒ GOOD', () {
      expect(engine.evaluate(1.5, t), Verdict.good); // boundary, inclusive
      expect(engine.evaluate(2.0, t), Verdict.good);
    });

    test('between the cuts ⇒ OK', () {
      expect(
        engine.evaluate(1.0, t),
        Verdict.ok,
      ); // badBelow boundary, inclusive
      expect(engine.evaluate(1.25, t), Verdict.ok);
      expect(engine.evaluate(1.49, t), Verdict.ok);
    });

    test('below the BAD cut ⇒ BAD', () {
      expect(engine.evaluate(0.99, t), Verdict.bad); // just under, exclusive
      expect(engine.evaluate(0.0, t), Verdict.bad);
    });

    test('OK band is [badBelow, goodAtOrAbove)', () {
      // The two boundaries land on the sides documented in ARCHITECTURE.md.
      expect(engine.evaluate(t.badBelow, t), Verdict.ok);
      expect(engine.evaluate(t.goodAtOrAbove, t), Verdict.good);
    });
  });

  group('Thresholds', () {
    test('defaults are a coherent band', () {
      expect(Thresholds.defaults.isValid, isTrue);
    });

    test('isValid catches an inverted band', () {
      const bad = Thresholds(goodAtOrAbove: 0.8, badBelow: 1.2);
      expect(bad.isValid, isFalse);
    });

    test('copyWith swaps only the named field', () {
      final t2 = t.copyWith(goodAtOrAbove: 2.0);
      expect(t2.goodAtOrAbove, 2.0);
      expect(t2.badBelow, t.badBelow);
    });

    test('value equality', () {
      expect(
        const Thresholds(goodAtOrAbove: 1.5, badBelow: 1.0),
        const Thresholds(goodAtOrAbove: 1.5, badBelow: 1.0),
      );
    });
  });

  group('DecisionEngine.scoreOffer — rate mode', () {
    // $9 / 6 km / 30 min ⇒ $1.50/km (GOOD by km) but $18/hr (BAD by hour):
    // one offer whose verdict FLIPS with the mode, so a wrong mode read fails.
    const offer = Offer(
      platform: GigPlatform.uber,
      payout: 9,
      pickupKm: 2,
      dropoffKm: 4,
      pickupMinutes: 10,
      dropoffMinutes: 20,
    );
    final perKm = FoxSettings.defaults; // rateMode: perKm
    final perHour = FoxSettings.defaults.copyWith(rateMode: RateMode.perHour);

    test(r'$/km mode scores by pricePerKm against the km cuts', () {
      expect(engine.scoreOffer(offer, perKm), Verdict.good); // 1.50/km
    });

    test(r'$/hr mode scores by pricePerHour against the hour cuts', () {
      expect(engine.scoreOffer(offer, perHour), Verdict.bad); // $18/hr < $20
    });

    test(r'$/hr mode falls back to $/km when the offer has no minutes', () {
      const noTime = Offer(
        platform: GigPlatform.uber,
        payout: 9,
        pickupKm: 2,
        dropoffKm: 4,
      );
      // Falls back to 1.50/km against the KM cuts → GOOD, not 0/hr → BAD.
      expect(engine.scoreOffer(noTime, perHour), Verdict.good);
    });

    test(r'$/hr boundaries: inclusive GOOD, exclusive BAD', () {
      Offer at(double perHourRate) => Offer(
        platform: GigPlatform.uber,
        payout: perHourRate,
        pickupKm: 1,
        dropoffKm: 1,
        pickupMinutes: 30,
        dropoffMinutes: 30,
      ); // payout over exactly 1 hour ⇒ rate == payout
      expect(engine.scoreOffer(at(30), perHour), Verdict.good); // inclusive
      expect(engine.scoreOffer(at(29.99), perHour), Verdict.ok);
      expect(engine.scoreOffer(at(20), perHour), Verdict.ok); // inclusive OK
      expect(engine.scoreOffer(at(19.99), perHour), Verdict.bad);
    });
  });
}
