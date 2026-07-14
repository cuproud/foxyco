import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/uber_parser.dart';

/// Fixtures = node-text dumps in view order, as the accessibility service would
/// hand them to us. Numbers taken from the real reference layouts
/// (references/Uber.jpg, references/new (1).jpg — docs/REFERENCE_ANALYSIS).
/// One fixture per real format; add a new one whenever Uber's card changes.
void main() {
  const parser = UberParser();

  test('parses a standard UberX card (pickup + trip split)', () {
    // references/Uber.jpg — $10.55 gross, 0.8 km pickup, 4.3 km trip.
    final nodes = [
      'UberX',
      'Exclusive',
      '\$10.55',
      '★ 4.95',
      '\$3.00 Boost+ included',
      '4 mins (0.8 km) away',
      '123 Anywhere St',
      '15 mins (4.3 km) trip',
      '456 Somewhere Ave',
      'Accept',
    ];

    final offer = parser.parse(nodes)!;

    expect(offer.platform, GigPlatform.uber);
    expect(offer.payout, 10.55);
    expect(offer.pickupKm, 0.8);
    expect(offer.dropoffKm, 4.3);
    expect(offer.pickupMinutes, 4);
    expect(offer.dropoffMinutes, 15);
    expect(offer.payIsNet, isFalse);
    // Derived: totalKm 5.1, $/km ≈ 2.07, $/hr over 19 min ≈ 33.3.
    expect(offer.totalKm, closeTo(5.1, 1e-9));
    expect(offer.pricePerKm, closeTo(2.069, 0.001));
    expect(offer.pricePerHour, closeTo(33.32, 0.1));
  });

  test('payout is the FIRST dollar amount, not a later boost line', () {
    final nodes = [
      'UberX',
      '\$8.00',
      '\$3.00 Boost+ included', // must NOT win
      '15 mins (4.3 km) trip',
      'Accept',
    ];
    expect(parser.parse(nodes)!.payout, 8.00);
  });

  test('trip-only card parses with zero pickup leg', () {
    final offer = parser.parse(['\$9.00', '20 mins (6.0 km) trip', 'Accept'])!;
    expect(offer.pickupKm, 0);
    expect(offer.dropoffKm, 6.0);
    expect(offer.totalKm, 6.0);
  });

  test('returns null when the trip distance is missing (fail safe)', () {
    // Acceptance-rate gate: pay shown, no upfront distances.
    expect(parser.parse(['\$12.00', 'Accept to see trip details']), isNull);
  });

  test('returns null without an Accept affordance (contract)', () {
    // Distances + pay present but no takeable action — treat as not-an-offer.
    expect(
      parser.parse(['\$10.55', '4 mins (0.8 km) away', '15 mins (4.3 km) trip']),
      isNull,
    );
  });

  test('returns null on the online/home map (browse markers)', () {
    // Uber's online screen: pay banners + surge, but no away/trip legs and no
    // Accept. Must never render a pill.
    expect(
      parser.parse([
        'You are online',
        '\$37.64',
        'Go Online',
        '\$10 trip nearby',
      ]),
      isNull,
    );
  });

  test('returns null on an empty / non-offer screen', () {
    expect(parser.parse(const []), isNull);
    expect(parser.parse(['Home', 'You are online']), isNull);
  });

  test('returns null when payout is absent', () {
    expect(
      parser.parse(['4 mins (0.8 km) away', '15 mins (4.3 km) trip', 'Accept']),
      isNull,
    );
  });
}
