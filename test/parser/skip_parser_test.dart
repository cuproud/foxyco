import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/skip_parser.dart';

void main() {
  const parser = SkipParser();

  test('parses the official Skip Courier offer card', () {
    final offer = parser.parse([
      r'$14.40 includes tip and bonus',
      '5 km total travel distance',
      '1 pickup',
      'The Pizza Place',
      'Arrive by 3:30 PM',
      '1 delivery',
      'Customer',
      'Arrive by 3:40 PM',
      'Accept offer',
      '59',
    ])!;

    expect(offer.platform, GigPlatform.skip);
    expect(offer.payout, 14.40);
    expect(offer.totalKm, 5);
    expect(offer.totalMinutes, 0);
    expect(offer.deliveryCount, 1);
  });

  test('converts miles and captures explicit shop workload', () {
    final offer = parser.parse([
      r'$18.25 total pay',
      'Shop + Pay · 12 items',
      'Partner pickup',
      'Customer delivery',
      '4.2 mi',
      'Accept',
    ])!;
    expect(offer.totalKm, closeTo(4.2 * DistanceUnit.kilometresPerMile, 1e-9));
    expect(offer.itemCount, 12);
  });

  test('rejects home, earnings and incomplete offer frames', () {
    expect(parser.parse([r'$14.40', '5 km', 'Matching you to orders']), isNull);
    expect(parser.parse([r'$14.40', '5 km', 'Pickup', 'Accept offer']), isNull);
    expect(
      parser.parse([r'$14.40', 'Pickup', 'Customer', 'Accept offer']),
      isNull,
    );
  });
}
