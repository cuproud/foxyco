import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';

void main() {
  test('legacy final payout adds its separately stored tip once', () {
    final legacy = OfferSummary.fromJson({
      'finalPayout': 50.44,
      'tip': 2.00,
      'tollReimbursement': 23.56,
    });

    expect(legacy.effectivePayout, 52.44);
    expect(legacy.performancePayout, closeTo(28.88, 1e-9));

    final restored = OfferSummary.fromJson(legacy.toJson());
    expect(restored.effectivePayout, 52.44);
    expect(restored.performancePayout, closeTo(28.88, 1e-9));
  });
}
