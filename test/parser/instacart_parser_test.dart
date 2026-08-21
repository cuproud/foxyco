import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/instacart_parser.dart';

void main() {
  const parser = InstacartParser();

  test('parses shop-and-deliver batch workload', () {
    final offer = parser.parse([
      r'$267.22',
      '3 shop and deliver · 29 items (36 units)',
      '9.6 mi',
      'Costco',
      'Accept',
    ])!;

    expect(offer.platform, GigPlatform.instacart);
    expect(offer.payout, 267.22);
    expect(offer.totalKm, closeTo(9.6 * DistanceUnit.kilometresPerMile, 1e-9));
    expect(offer.deliveryCount, 3);
    expect(offer.itemCount, 29);
    expect(offer.unitCount, 36);
  });

  test('parses delivery-only card without item counts', () {
    final offer = parser.parse([
      r'$14.00',
      'Delivery only',
      '3.0 mi',
      'Accept',
    ])!;
    expect(offer.deliveryCount, 1);
    expect(offer.itemCount, 0);
  });

  test('rejects list-only, shop-only and incomplete frames', () {
    expect(
      parser.parse([
        r'$267.22',
        '3 shop and deliver · 29 items (36 units)',
        '9.6 mi',
      ]),
      isNull,
    );
    expect(parser.parse([r'$20.00', 'Shop only · 12 items', 'Accept']), isNull);
    expect(
      parser.parse([r'$20.00', 'Shop and deliver', '4.0 mi', 'Accept']),
      isNull,
    );
  });
}
