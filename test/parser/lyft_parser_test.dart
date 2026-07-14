import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/lyft_parser.dart';

/// Fixtures from the real Lyft layouts (references/new (3)-(5).jpg). Same
/// dot-line timeline as Hopp: first leg = pickup, last = dropoff. Lyft pay is
/// gross, with a bonus line + a "$/hr est. rate" line that must NOT be read as
/// the payout.
void main() {
  const parser = LyftParser();

  test('parses a standard Lyft card, legs pickup→dropoff', () {
    // references/new (3).jpg — $9.01, 0.4 km pickup, 7.2 km dropoff, 19 min.
    final nodes = [
      '\$9.01',
      'Incl. CA\$1.50 bonus',
      '\$28.45/hr est. rate for this ride',
      '3 mins · 0.4 km',
      'Yonge, Richmond Hill',
      '16 mins · 7.2 km',
      'Gatineau & New Westminster, Thornhill',
      'Tony',
      '5.0',
      'Lyft',
      'Accept',
    ];

    final offer = parser.parse(nodes)!;

    expect(offer.platform, GigPlatform.lyft);
    expect(offer.payout, 9.01); // NOT 1.50 (bonus) or 28.45 (rate)
    expect(offer.pickupKm, 0.4);
    expect(offer.dropoffKm, 7.2);
    expect(offer.pickupMinutes, 3);
    expect(offer.dropoffMinutes, 16);
    expect(offer.payIsNet, isFalse);
    expect(offer.totalKm, closeTo(7.6, 1e-9));
    // Sanity vs Lyft's own printed rate: $9.01 / 19min * 60 ≈ $28.45/hr.
    expect(offer.pricePerHour, closeTo(28.45, 0.05));
  });

  test('payout is the first \$ — skips the bonus and rate lines', () {
    final nodes = [
      '\$21.11',
      'Incl. CA\$4.87 in bonuses',
      '\$39.58/hr est. rate for this ride',
      '7 mins · 2.6 km',
      '25 mins · 18.1 km',
      'Accept',
    ];
    expect(parser.parse(nodes)!.payout, 21.11);
  });

  test('returns null with only one leg (fail safe)', () {
    expect(parser.parse(['\$9.01', '3 mins · 0.4 km', 'Accept']), isNull);
  });

  test('returns null without an Accept affordance (contract)', () {
    // A perfectly-shaped card body but no Accept button = not a live offer.
    expect(
      parser.parse(['\$9.01', '3 mins · 0.4 km', '16 mins · 7.2 km']),
      isNull,
    );
  });

  test('rejects the home/scheduled-rides screen (flicker regression)', () {
    // Real device capture 2026-07-12: Lyft's online/home screen lists SUGGESTED
    // SCHEDULED RIDE cards, each with its own leg. We were stitching two into a
    // fake $11.26 / 45.3 km offer and flickering the pill. Must parse to null.
    final nodes = [
      "You're online",
      "We're looking for rides.",
      'Earnings Goal',
      'Turbo Zones',
      '29 rides available',
      'SUGGESTED SCHEDULED RIDE',
      '\$11.26 Extra Comfort ride',
      '15 mins • 20.7 km',
      '3:30 a.m.',
      'SUGGESTED SCHEDULED RIDE',
      '\$14.83 Lyft ride',
      '21 mins • 27.6 km',
      '4:00 a.m.',
      'Accept', // even if an Accept leaks in, browse markers still reject
    ];
    expect(parser.parse(nodes), isNull);
  });

  test('rejects the Ride Finder browse map — bug1 (6)', () {
    // The $37.64 | 3 Turbo/streak banner + a "$10 Lyft · 2 min away" map bubble.
    // No km legs, no Accept, "Ride Finder" marker present. The old parser
    // grabbed the banner $37.64 and mashed map distances into a fake BAD offer.
    final nodes = [
      '\$37.64',
      '3',
      'Busy',
      '\$10 Lyft',
      '2 min away',
      '1 ride available on the map',
      'Select a ride on the map to review',
      'Ride Finder',
      '1 new',
      'Earnings Goal',
    ];
    expect(parser.parse(nodes), isNull);
  });

  test('rejects the online map with pickup bubbles — bug1 (8)', () {
    // Several "$N Lyft · M min away" bubbles + the streak banner. Crucially the
    // bubbles have NO "km", so none is a leg → no fake trip can be built.
    final nodes = [
      '\$37.64',
      '3',
      '\$5 Lyft',
      '\$12 Lyft',
      '1 min away',
      '\$3 Lyft',
      '3 min away',
      '1 to 2 min wait in your area',
      'Expected for the next 10 min',
      'Priority Mode',
      'Go Online',
      'Ride Finder',
    ];
    expect(parser.parse(nodes), isNull);
  });

  test('parses a MULTI-STOP ride, summing every leg after pickup into trip', () {
    // pickup = 20.7 km / 15 min; trip = 27.6 + 22.0 = 49.6 km, 21 + 18 = 39 min.
    final offer = parser.parse([
      '\$11.26 ride',
      '15 mins • 20.7 km',
      '21 mins • 27.6 km',
      '18 mins • 22.0 km',
      'Accept',
    ])!;
    expect(offer.pickupKm, 20.7);
    expect(offer.dropoffKm, closeTo(49.6, 1e-9)); // 27.6 + 22.0
    expect(offer.dropoffMinutes, 39); // 21 + 18
    expect(offer.totalKm, closeTo(70.3, 1e-9));
  });

  test('rejects too many legs (a ride LIST, not one multi-stop card)', () {
    // Above the multi-stop cap → assume a stitched list; fail safe.
    final nodes = [
      '\$11.26 ride',
      '1 min • 1 km', '2 mins • 2 km', '3 mins • 3 km',
      '4 mins • 4 km', '5 mins • 5 km', '6 mins • 6 km', '7 mins • 7 km',
      'Accept',
    ];
    expect(parser.parse(nodes), isNull);
  });

  test('returns null when payout missing / empty screen', () {
    expect(
      parser.parse(['3 mins · 0.4 km', '16 mins · 7.2 km', 'Accept']),
      isNull,
    );
    expect(parser.parse(const []), isNull);
  });
}
