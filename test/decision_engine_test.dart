import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/decision_engine.dart';
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
      expect(engine.evaluate(1.0, t), Verdict.ok); // badBelow boundary, inclusive
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
}
