import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/hopp_parser.dart';

/// Fixtures from the real Hopp layouts (references/Hopp.jpg, references/new (2).jpg
/// — docs/REFERENCE_ANALYSIS). Hopp doesn't label the two legs away/trip, so the
/// parser relies on view ORDER: first leg = pickup, last = dropoff.
void main() {
  const parser = HoppParser();

  test('parses a NET Hopp card, legs ordered pickup→dropoff', () {
    // references/new (2).jpg — $8.50 net, 5.2 km pickup, 7.7 km dropoff.
    final nodes = [
      'Hopp',
      'Card',
      'Out of radius',
      '\$8.50',
      '(NET, tax included)',
      "Declining won't affect acceptance rate",
      'Alex • 5.0 ★ (6)',
      '11 min · 5.2 km',
      '91 Paperbark Avenue, Vaughan L6A 0Y1',
      '11 min · 7.7 km',
      '43 Matterhorn Rd, Vaughan L6A 2V5',
      'Match',
    ];

    final offer = parser.parse(nodes)!;

    expect(offer.platform, GigPlatform.hopp);
    expect(offer.payout, 8.50);
    expect(offer.pickupKm, 5.2);
    expect(offer.dropoffKm, 7.7);
    expect(offer.pickupMinutes, 11);
    expect(offer.dropoffMinutes, 11);
    expect(offer.payIsNet, isTrue);
    expect(offer.totalKm, closeTo(12.9, 1e-9));
    // $8.50 / 12.9 km ≈ 0.659 $/km.
    expect(offer.pricePerKm, closeTo(0.659, 0.001));
  });

  test('picks the payout over a Toll Fee line above it (real 407 trip)', () {
    // Captured on device 2026-07-12: Hopp shows "Toll Fee • $2.10" ABOVE the
    // real "$14.66 (NET…)" payout. Naive first-$ grabbed $2.10 — regression.
    final nodes = [
      'Decline',
      'Hopp',
      'Card',
      'Toll Fee • \$2.10',
      '\$14.66 (NET, tax included)',
      'Aida • 5.0 ★ (20)',
      '1 min • 0.6 km',
      '5645 Yonge St, Toronto M2M 3T2',
      '26 min • 20.9 km',
      '100 Somewhere Rd',
      'Match',
    ];
    final offer = parser.parse(nodes)!;
    expect(offer.payout, 14.66); // NOT 2.10
    expect(offer.payIsNet, isTrue);
    expect(offer.totalKm, closeTo(21.5, 1e-9));
  });

  test('sets payIsNet=false when no NET / tax-included marker is present', () {
    final nodes = ['\$20.00', '3 min · 1.0 km', '15 min · 8.0 km', 'Match'];
    expect(parser.parse(nodes)!.payIsNet, isFalse);
  });

  test('tolerates a bullet or hyphen separator between time and distance', () {
    final nodes = ['\$15.65', '3 min • 1.1 km', '34 min - 46.3 km', 'Match'];
    final offer = parser.parse(nodes)!;
    expect(offer.pickupKm, 1.1);
    expect(offer.dropoffKm, 46.3);
  });

  test('returns null with only one leg (half-rendered card, fail safe)', () {
    expect(
      parser.parse(['\$8.50', '(NET)', '11 min · 5.2 km', 'Match']),
      isNull,
    );
  });

  test(
    'parses a MULTI-STOP ride, summing every leg after pickup into trip',
    () {
      // A ride with one stop is 3 legs: pickup, then stop, then final dropoff.
      // pickup = 5.2 km / 11 min; trip = 7.7 + 4.1 = 11.8 km, 11 + 9 = 20 min.
      final offer = parser.parse([
        '\$8.50',
        '11 min · 5.2 km',
        '11 min · 7.7 km',
        '9 min · 4.1 km',
        'Match',
      ])!;
      expect(offer.pickupKm, 5.2);
      expect(offer.dropoffKm, closeTo(11.8, 1e-9)); // 7.7 + 4.1
      expect(offer.pickupMinutes, 11);
      expect(offer.dropoffMinutes, 20); // 11 + 9
      expect(offer.totalKm, closeTo(17.0, 1e-9));
    },
  );

  test('returns null with too many legs (a ride LIST, not one card)', () {
    // Above the multi-stop cap → assume we latched onto a list; fail safe.
    expect(
      parser.parse([
        '\$8.50',
        '1 min · 1 km',
        '2 min · 2 km',
        '3 min · 3 km',
        '4 min · 4 km',
        '5 min · 5 km',
        '6 min · 6 km',
        '7 min · 7 km',
        'Match',
      ]),
      isNull,
    );
  });

  test('returns null when payout is missing', () {
    expect(
      parser.parse(['11 min · 5.2 km', '11 min · 7.7 km', 'Match']),
      isNull,
    );
  });

  test('returns null without an Accept/Match affordance (contract)', () {
    // Every clause but the takeable action — still not a real offer card.
    expect(
      parser.parse(['\$8.50', '(NET)', '11 min · 5.2 km', '11 min · 7.7 km']),
      isNull,
    );
  });

  test('returns null on an empty / non-offer screen', () {
    expect(parser.parse(const []), isNull);
    expect(parser.parse(['Go online', 'Current shift']), isNull);
  });
}
