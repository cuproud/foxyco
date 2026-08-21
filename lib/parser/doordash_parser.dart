import '../domain/distance_unit.dart';
import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Conservative DoorDash beta parser seeded from public 2024–2026 cards.
/// Missing route distance or guaranteed pay returns null; absolute "deliver
/// by" times are never treated as job duration.
class DoorDashParser implements OfferParser {
  const DoorDashParser();

  @override
  GigPlatform get platform => GigPlatform.doorDash;

  @override
  String get tunedAgainst => 'DoorDash public cards 2024–2026 (Beta)';

  static final _action = RegExp(r'\baccept(?:er)?\b', caseSensitive: false);
  static final _guaranteed = RegExp(
    r'\bguaranteed\b|\bgarantie\b',
    caseSensitive: false,
  );
  static final _route = RegExp(
    r'\b(customer\s+dropoff|deliver\s+by|restaurant\s+pickup|pickup|'
    r'retail\s+delivery|livrer\s+avant|livraison\s+d[’\x27]articles|remise)\b',
    caseSensitive: false,
  );
  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|mi|miles?)\b',
    caseSensitive: false,
  );
  static final _money = RegExp(
    r'(?:CA\s*)?\$\s*(\d+(?:[.,]\d{1,2})?)|'
    r'(\d+(?:[.,]\d{1,2})?)\s*\$',
    caseSensitive: false,
  );
  static final _items = RegExp(
    r'\b(\d+)\s*(?:items?|articles?)\b',
    caseSensitive: false,
  );

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');
    if (!_action.hasMatch(joined) ||
        !_guaranteed.hasMatch(joined) ||
        !_route.hasMatch(joined)) {
      return null;
    }

    final money = _money.firstMatch(joined);
    final distance = _distance.firstMatch(joined);
    if (money == null || distance == null) return null;

    final payout = double.tryParse(
      (money.group(1) ?? money.group(2)!).replaceAll(',', '.'),
    );
    final rawDistance = double.tryParse(
      distance.group(1)!.replaceAll(',', '.'),
    );
    if (payout == null ||
        payout <= 0 ||
        rawDistance == null ||
        rawDistance <= 0) {
      return null;
    }

    final unit = distance.group(2)!.toLowerCase();
    final totalKm = unit == 'mi' || unit.startsWith('mile')
        ? rawDistance * DistanceUnit.kilometresPerMile
        : rawDistance;
    final itemCount =
        int.tryParse(_items.firstMatch(joined)?.group(1) ?? '') ?? 0;
    final pickupCount = RegExp(
      r'\b(?:restaurant\s+)?pickup\b',
      caseSensitive: false,
    ).allMatches(joined).length;
    final retail =
        itemCount > 0 ||
        RegExp(
          r'\bretail\s+delivery\b|livraison\s+d[’\x27]articles',
          caseSensitive: false,
        ).hasMatch(joined);

    return Offer(
      platform: GigPlatform.doorDash,
      payout: payout,
      pickupKm: 0,
      dropoffKm: totalKm,
      category: retail ? 'Shop & deliver · Beta' : 'Delivery · Beta',
      deliveryCount: pickupCount > 1 ? pickupCount : 1,
      itemCount: itemCount,
      rawText: joined,
    );
  }
}
