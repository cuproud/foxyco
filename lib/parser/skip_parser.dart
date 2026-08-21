import '../domain/distance_unit.dart';
import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Conservative Skip Courier beta parser seeded from current official cards.
/// Arrival clock times are context only and never treated as job duration.
class SkipParser implements OfferParser {
  const SkipParser();

  @override
  GigPlatform get platform => GigPlatform.skip;

  @override
  String get tunedAgainst => 'Skip official Courier card 2026 (Beta)';

  static final _pickup = RegExp(
    r'\b(pick\s*up|collect|partner|restaurant)\b',
    caseSensitive: false,
  );
  static final _dropoff = RegExp(
    r'\b(deliver(?:y)?|drop[ -]?off|customer)\b',
    caseSensitive: false,
  );
  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|mi|miles?)\b',
    caseSensitive: false,
  );
  static final _items = RegExp(r'\b(\d+)\s+items?\b', caseSensitive: false);

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');
    if (!ParserPatterns.hasAcceptAction(nodeTexts) ||
        !_pickup.hasMatch(joined) ||
        !_dropoff.hasMatch(joined)) {
      return null;
    }

    final payout = ParserPatterns.findPayout(nodeTexts);
    final distance = _distance.firstMatch(joined);
    if (payout == null || distance == null) return null;
    final rawDistance = double.tryParse(
      distance.group(1)!.replaceAll(',', '.'),
    );
    if (rawDistance == null || rawDistance <= 0) return null;

    final unit = distance.group(2)!.toLowerCase();
    final totalKm = unit == 'mi' || unit.startsWith('mile')
        ? rawDistance * DistanceUnit.kilometresPerMile
        : rawDistance;
    final itemCount =
        int.tryParse(_items.firstMatch(joined)?.group(1) ?? '') ?? 0;
    final shopAndPay = RegExp(
      r'\bshop\s*(?:\+|and)\s*pay\b',
      caseSensitive: false,
    ).hasMatch(joined);

    return Offer(
      platform: GigPlatform.skip,
      payout: payout,
      pickupKm: 0,
      dropoffKm: totalKm,
      category: '${shopAndPay ? 'Shop & pay' : 'Delivery'} · Beta',
      deliveryCount: 1,
      itemCount: itemCount,
      rawText: joined,
    );
  }
}
