import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/verdict.dart';

void main() {
  group('OverlayPayload — the cross-isolate wire format', () {
    test('round-trips through toMap/fromMap', () {
      const p = OverlayPayload(
        verdict: Verdict.good,
        totalKm: 8.4,
        payout: 12,
        size: PillSize.large,
      );
      final back = OverlayPayload.fromMap(p.toMap());
      expect(back.verdict, Verdict.good);
      expect(back.totalKm, 8.4);
      expect(back.payout, 12);
      expect(back.size, PillSize.large);
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
  });
}
