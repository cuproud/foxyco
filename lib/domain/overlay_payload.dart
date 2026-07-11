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
  final PillSize size;

  const OverlayPayload({
    required this.verdict,
    required this.totalKm,
    required this.payout,
    this.size = PillSize.medium,
  });

  double get pricePerKm => totalKm > 0 ? payout / totalKm : 0;

  /// Serialize to a primitive map for `shareData`. Enums go across as their
  /// stable `name` string — never the index, which can shift if we reorder.
  /// Tagged `kind: 'offer'` so the overlay can tell offers apart from control
  /// and action messages sharing the same channel.
  Map<String, dynamic> toMap() => {
        'kind': 'offer',
        'verdict': verdict.name,
        'totalKm': totalKm,
        'payout': payout,
        'size': size.name,
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
        size: PillSize.values.firstWhere(
          (s) => s.name == map['size'],
          orElse: () => PillSize.medium,
        ),
      );
}
