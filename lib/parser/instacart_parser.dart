import '../domain/distance_unit.dart';
import '../domain/offer.dart';
import '../domain/platform.dart';
import 'offer_parser.dart';

/// Conservative Instacart beta parser seeded from public batch cards.
/// Shop-only batches are deliberately rejected because a driving-distance
/// verdict would misrepresent shopping work.
class InstacartParser implements OfferParser {
  const InstacartParser();

  @override
  GigPlatform get platform => GigPlatform.instacart;

  @override
  String get tunedAgainst => 'Instacart public batch cards 2024–2026 (Beta)';

  static final _type = RegExp(
    r'\b(?:(\d+)\s+)?(shop\s+and\s+deliver|delivery\s+only)\b',
    caseSensitive: false,
  );
  static final _items = RegExp(
    r'\b(\d+)\s+items?\s*(?:\(\s*(\d+)\s+units?\s*\))?',
    caseSensitive: false,
  );
  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|mi|miles?)\b',
    caseSensitive: false,
  );

  @override
  Offer? parse(List<String> nodeTexts) {
    final joined = nodeTexts.join(' ');
    if (!ParserPatterns.hasAcceptAction(nodeTexts)) return null;

    final type = _type.firstMatch(joined);
    final distance = _distance.firstMatch(joined);
    final payout = ParserPatterns.findPayout(nodeTexts);
    if (type == null || distance == null || payout == null) return null;

    final rawDistance = double.tryParse(
      distance.group(1)!.replaceAll(',', '.'),
    );
    if (rawDistance == null || rawDistance <= 0) return null;
    final unit = distance.group(2)!.toLowerCase();
    final totalKm = unit == 'mi' || unit.startsWith('mile')
        ? rawDistance * DistanceUnit.kilometresPerMile
        : rawDistance;

    final shopAndDeliver = type.group(2)!.toLowerCase().startsWith('shop');
    final items = _items.firstMatch(joined);
    if (shopAndDeliver && items == null) return null;

    final deliveries = (int.tryParse(type.group(1) ?? '') ?? 1).clamp(1, 3);
    final itemCount = int.tryParse(items?.group(1) ?? '') ?? 0;
    final unitCount = int.tryParse(items?.group(2) ?? '') ?? itemCount;
    return Offer(
      platform: GigPlatform.instacart,
      payout: payout,
      pickupKm: 0,
      dropoffKm: totalKm,
      category: '${shopAndDeliver ? 'Shop & deliver' : 'Delivery only'} · Beta',
      deliveryCount: deliveries,
      itemCount: itemCount,
      unitCount: unitCount,
      rawText: joined,
    );
  }
}
