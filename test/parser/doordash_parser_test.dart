import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/doordash_parser.dart';

void main() {
  const parser = DoorDashParser();

  test('parses official redesigned single-delivery card', () {
    final offer = parser.parse([
      r'$7.50 Guaranteed (incl. tips)',
      '1.6 mi',
      'Deliver by 10:45 AM',
      'Restaurant pickup',
      'Frosty Bear',
      'Customer dropoff',
      'Accept',
      '30',
    ])!;

    expect(offer.platform, GigPlatform.doorDash);
    expect(offer.payout, 7.50);
    expect(offer.totalKm, closeTo(1.6 * DistanceUnit.kilometresPerMile, 1e-9));
    expect(offer.totalMinutes, 0);
    expect(offer.deliveryCount, 1);
  });

  test('parses batched pickup count', () {
    final offer = parser.parse([
      r'$11.00 Guaranteed',
      '2.9 mi',
      'Deliver by 8:22 PM',
      "Pickup Wendy's",
      'Pickup Homeroom',
      'Customer dropoff',
      'Accept',
    ])!;
    expect(offer.deliveryCount, 2);
  });

  test(
    'parses Canadian French retail card without treating deadline as time',
    () {
      final offer = parser.parse([
        r'6,75 $ Garantie (incl. pourboires)',
        '4.9 km',
        'Livrer avant le 18 h 13',
        'Livraison d’articles de détail',
        'Walmart 3148 (16 articles)',
        'Remise d’entreprise',
        'Accepter',
        '39',
      ])!;
      expect(offer.payout, 6.75);
      expect(offer.totalKm, 4.9);
      expect(offer.itemCount, 16);
      expect(offer.totalMinutes, 0);
    },
  );

  test('rejects incomplete and non-offer frames', () {
    expect(parser.parse([r'$7.50', '1.6 mi', 'Accept']), isNull);
    expect(
      parser.parse([
        r'$7.50 Guaranteed',
        'Deliver by 10:45 AM',
        'Customer dropoff',
        'Accept',
      ]),
      isNull,
    );
    expect(parser.parse(['Dash now', r'$20.00', '4.2 mi']), isNull);
  });
}
