import 'money_font.dart';
import 'verdict.dart';

/// Pill display sizes the driver can cycle (docs/OVERLAY — resizable S/M/L).
enum PillSize { small, medium, large }

/// The cross-isolate contract between the main app and the overlay isolate.
///
/// The overlay runs in its own isolate with NO shared memory, so everything the
/// pill needs to draw must survive a trip through
/// `FlutterOverlayWindow.shareData(Map)`. Keep this tiny and primitive-only —
/// [toMap]/[fromMap] are the whole wire format. Pure Dart, no plugin imports,
/// so both isolates and the tests can use it.
class OverlayPayload {
  final Verdict verdict;
  final double totalKm;
  final double payout; // dollars
  final double totalMinutes; // pickup + trip; 0 when unknown
  final PillSize size;

  /// Dead mileage to the rider; 0 when the parser couldn't split it out.
  final double pickupKm;

  /// The driver's "near pickup" cutoff (Settings). At/under → the pill paints
  /// the km stat green; over → red. 0 disables the coloring.
  final double pickupNearKm;

  /// Typeface for the pill's money numbers (Settings → Appearance). Carried in
  /// the payload because the overlay isolate can't read SharedPreferences from
  /// the main isolate's provider.
  final MoneyFont moneyFont;

  const OverlayPayload({
    required this.verdict,
    required this.totalKm,
    required this.payout,
    this.totalMinutes = 0,
    this.size = PillSize.medium,
    this.pickupKm = 0,
    this.pickupNearKm = 0,
    this.moneyFont = MoneyFont.inter,
  });

  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;

  /// Dollars per hour — the Maxymo-style headline. Zero when no time was parsed,
  /// so the pill hides it rather than dividing by zero.
  double get pricePerHour => totalMinutes > 0 ? payout / totalMinutes * 60 : 0;

  /// Whether the km stat should be verdict-colored, and which way. Null means
  /// "no signal" (unknown pickup or feature disabled) → default cream.
  bool? get pickupIsNear {
    if (pickupKm <= 0 || pickupNearKm <= 0) return null;
    return pickupKm <= pickupNearKm;
  }

  /// Serialize to a primitive map for `shareData`. Enums go across as their
  /// stable `name` string — never the index, which can shift if we reorder.
  /// Tagged `kind: 'offer'` so the overlay can tell offers apart from control
  /// and action messages sharing the same channel.
  Map<String, dynamic> toMap() => {
    'kind': 'offer',
    'verdict': verdict.name,
    'totalKm': totalKm,
    'payout': payout,
    'totalMinutes': totalMinutes,
    'size': size.name,
    'pickupKm': pickupKm,
    'pickupNearKm': pickupNearKm,
    'moneyFont': moneyFont.name,
  };

  /// Rebuild from a `shareData` map on the overlay side. Fails safe: unknown or
  /// missing fields degrade to [Verdict.unknown] / medium rather than throwing,
  /// so a bad payload never crashes the overlay isolate.
  factory OverlayPayload.fromMap(Map<dynamic, dynamic> map) => OverlayPayload(
    verdict: Verdict.values.firstWhere(
      (v) => v.name == map['verdict'],
      orElse: () => Verdict.unknown,
    ),
    totalKm: (map['totalKm'] as num?)?.toDouble() ?? 0,
    payout: (map['payout'] as num?)?.toDouble() ?? 0,
    totalMinutes: (map['totalMinutes'] as num?)?.toDouble() ?? 0,
    size: PillSize.values.firstWhere(
      (s) => s.name == map['size'],
      orElse: () => PillSize.medium,
    ),
    pickupKm: (map['pickupKm'] as num?)?.toDouble() ?? 0,
    pickupNearKm: (map['pickupNearKm'] as num?)?.toDouble() ?? 0,
    moneyFont: MoneyFont.fromName(map['moneyFont'] as String?),
  );
}
