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
      parser.parse([
        '\$10.55',
        '4 mins (0.8 km) away',
        '15 mins (4.3 km) trip',
      ]),
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

  test('real device: card merged with map chrome — Quest \$ must not win', () {
    // uiautomator win_1.xml 2026-07-19. The a11y walk merges every same-package
    // window, and the MAP subtree comes first, so its Quest banner ("$20 extra
    // for 30 trips") precedes the card's payout in node order.
    final nodes = [
      'Home',
      '8%',
      'Search for places',
      'Quest',
      '\$20 extra for 30 trips',
      '1/30',
      'Unlock Platinum',
      '482 / 900 pts',
      'UberX',
      'Exclusive',
      '\$4.06',
      '4.98',
      '7 mins (2.9 km) away',
      '347 Kingsdale Ave, North York',
      '4 mins (1.4 km) trip',
      '2901 Bayview Ave, Toronto',
      'Accept',
    ];
    final offer = parser.parse(nodes)!;
    expect(offer.payout, 4.06);
    expect(offer.pickupKm, 2.9);
    expect(offer.dropoffKm, 1.4);
  });

  test('long trip "1 hr 2 min" keeps the hour (device 2026-07-23 \$342/hr bug)',
      () {
    // Screenshot_20260723 — $34.22 over a 1 hr 2 min (62 min) trip. Before the
    // optional-hours fix the regex grabbed only "2 min", so $/hr read ~$342.
    final offer = parser.parse([
      'UberX',
      '\$34.22',
      '4.86',
      '4 mins (0.8 km) away',
      '5700 Yonge St, North York',
      '1 hr 2 min (54.6 km) trip',
      '1337 Copley Ct, Milton',
      'Match',
    ])!;
    expect(offer.dropoffMinutes, 62);
    expect(offer.totalMinutes, 66); // 4 pickup + 62 trip
    expect(offer.pricePerHour, closeTo(31.11, 0.1)); // NOT ~342
  });

  test('tags the ride category (tier + radar)', () {
    String? cat(List<String> n) => parser.parse(n)?.category;
    // Plain UberX dispatch.
    expect(
      cat(['UberX', '\$9', '15 mins (4.3 km) trip', 'Accept']),
      'UberX',
    );
    // Comfort dispatch.
    expect(
      cat(['Uber Comfort', '\$12', '15 mins (4.3 km) trip', 'Accept']),
      'Comfort',
    );
    // Share.
    expect(
      cat(['Uber Share', '\$7', '15 mins (4.3 km) trip', 'Accept']),
      'Share',
    );
    // Radar match on a UberX card (Match affordance, no Accept).
    expect(
      cat(['UberX', '\$9', '15 mins (4.3 km) trip', 'Match']),
      'UberX · Radar',
    );
  });

  test('real device: Trip Radar stacked card uses Match, not Accept', () {
    // uiautomator win_8.xml 2026-07-19 — busy-period Radar card.
    final offer = parser.parse([
      'UberX',
      '\$6.80',
      '5.00',
      '7 mins (2.8 km) away',
      'Subway',
      '12 mins (5.0 km) trip',
      '81 Glendora Ave',
      'Match',
    ])!;
    expect(offer.payout, 6.80);
    expect(offer.pickupKm, 2.8);
    expect(offer.dropoffKm, 5.0);
  });
}
