import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_currency.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/money_font.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/verdict.dart';

void main() {
  group('OverlayPayload — the cross-isolate wire format', () {
    test('round-trips through toMap/fromMap', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 8.4,
        payout: 12,
        totalMinutes: 24,
        size: PillSize.large,
        deliveryCount: 3,
      );
      final back = OverlayPayload.fromMap(p.toMap());
      expect(back.verdict, Verdict.good);
      expect(back.totalKm, 8.4);
      expect(back.payout, 12);
      expect(back.totalMinutes, 24);
      expect(back.size, PillSize.large);
      expect(back.deliveryCount, 3);
    });

    test('carries \$/hr; drops it when time is unknown', () {
      const withTime = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 8.4,
        payout: 12,
        totalMinutes: 24,
      );
      expect(withTime.pricePerHour, closeTo(30, 1e-9)); // $12 / 24min * 60

      const noTime = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 8.4,
        payout: 12,
      );
      expect(noTime.pricePerHour, 0); // hidden rather than ∞
    });

    test('enums cross as stable name strings, not indexes', () {
      final map = const OverlayPayload(
        verdict: Verdict.bad,
        totalKm: 1,
        payout: 1,
      ).toMap();
      expect(map['verdict'], 'bad');
      expect(map['size'], 'medium');
    });

    test('fails safe on a garbage payload', () {
      final p = OverlayPayload.fromMap({'verdict': 'nonsense', 'size': 'xl'});
      expect(p.verdict, Verdict.unknown); // never a confident wrong call
      expect(p.size, PillSize.medium);
      expect(p.totalKm, 0);
      expect(p.payout, 0);
    });

    test('pricePerKm guards divide-by-zero', () {
      const p = OverlayPayload(verdict: Verdict.unknown, totalKm: 0, payout: 5);
      expect(p.pricePerKm, 0);
    });

    test('moneyFont round-trips through shareData map', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 5,
        payout: 10,
        moneyFont: MoneyFont.spaceGrotesk,
      );
      expect(
        OverlayPayload.fromMap(p.toMap()).moneyFont,
        MoneyFont.spaceGrotesk,
      );
    });

    test('moneyFont missing from map falls back to inter', () {
      const p = OverlayPayload(verdict: Verdict.good, totalKm: 5, payout: 10);
      final m = p.toMap()..remove('moneyFont');
      expect(OverlayPayload.fromMap(m).moneyFont, MoneyFont.inter);
    });
  });

  // The overlay isolate has no Riverpod, no prefs and no clock it trusts, so
  // this flag is its ENTIRE entitlement rule (MONETIZATION_v1.0 §4). Every case
  // that isn't a literal `true` must render the locked pill — a patch that
  // strips the flag out of the main isolate has to fail closed.
  group('OverlayPayload.entitled — fails closed', () {
    test('defaults to locked when not specified', () {
      const p = OverlayPayload(verdict: Verdict.good, totalKm: 5, payout: 10);
      expect(p.entitled, isFalse);
    });

    test('round-trips true', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 5,
        payout: 10,
        entitled: true,
      );
      expect(OverlayPayload.fromMap(p.toMap()).entitled, isTrue);
    });

    test('a stripped flag reads as locked', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 5,
        payout: 10,
        entitled: true,
      );
      final tampered = p.toMap()..remove('entitled');
      expect(OverlayPayload.fromMap(tampered).entitled, isFalse);
    });

    test('only a literal true unlocks — not null, 1, or "true"', () {
      for (final forged in <Object?>[null, 1, 'true', 'yes', {}]) {
        final p = OverlayPayload.fromMap({
          'verdict': 'good',
          'totalKm': 5,
          'payout': 10,
          'entitled': forged,
        });
        expect(p.entitled, isFalse, reason: 'forged value: $forged');
      }
    });

    test('round-trips US display preferences and derives display values', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 1.609344,
        payout: 8,
        distanceUnit: DistanceUnit.miles,
        currency: AppCurrency.usd,
      );
      final restored = OverlayPayload.fromMap(p.toMap());
      expect(restored.distanceUnit, DistanceUnit.miles);
      expect(restored.currency, AppCurrency.usd);
      expect(restored.displayDistance, closeTo(1, 1e-9));
      expect(restored.displayRate, closeTo(8, 1e-9));
    });
  });
}
