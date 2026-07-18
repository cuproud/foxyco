import 'package:flutter/material.dart';

import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../theme/tokens.dart';

/// The floating verdict pill (references/foxyco_pill_v9.html — "split-color").
///
/// Two fused blocks: a verdict-colored block leading with the headline **$/km**
/// (the number that decides the verdict, so its color carries the call), fused
/// to a near-black block with the trip **km** and **$/hr**. A recessed seam and
/// glass sheen make it read as one compact HUD chip over the driver's map.
///
/// Plain widget, no plugin imports — renders identically in the overlay isolate
/// and an in-app preview, so it's buildable/eyeballable without a device.
class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.payload, this.size});

  final OverlayPayload payload;

  /// Overrides [OverlayPayload.size]. The floating overlay forces
  /// [PillSize.small] to fit the compact draggable window.
  final PillSize? size;

  // Pill-specific verdict fills (references/*pill* :root — a touch deeper than
  // the on-dark seg colors so the light block still reads on a bright map).
  static const _good = Color(0xFF39A96C);
  static const _ok = Color(0xFFE4A83C);
  static const _bad = Color(0xFFE56458);
  static const _unknown = Color(0xFF8895A7);

  Color get _rateColor => switch (payload.verdict) {
    Verdict.good => _good,
    Verdict.ok => _ok,
    Verdict.bad => _bad,
    Verdict.unknown => _unknown,
  };

  @override
  Widget build(BuildContext context) {
    final m = _metrics(size ?? payload.size);
    final perKm = '\$${payload.pricePerKm.toStringAsFixed(2)}';

    // Sheen goes from a lightened verdict color to the base — keeps the block
    // its verdict color (a plain white->transparent gradient would erase it,
    // since a BoxDecoration paints the gradient INSTEAD of `color`).
    final sheenTop = Color.lerp(_rateColor, Colors.white, 0.22)!;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          // One tight, neutral drop shadow. The old verdict-colored glow +
          // wide dark blur painted a smeary gradient across the overlay
          // window box over the map — looked like a dirty halo, not depth.
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E141C17),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored rate block — the $/km headline, verdict-tinted.
            Container(
              padding: EdgeInsets.fromLTRB(
                  m.padH + 1, m.padV, m.padH - 1, m.padV),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [sheenTop, _rateColor],
                  stops: const [0, 0.7],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    perKm,
                    style: TextStyle(
                      fontFamily: FoxFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: m.rate,
                      height: 1,
                      letterSpacing: -0.4,
                      color: const Color(0xFF141C17),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '/km',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: m.unit,
                      color: const Color(0xFF141C17).withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            // Dark info block — trip km + $/hr.
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: m.padH, vertical: m.padV),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF203026), Color(0xFF141C17), Color(0xFF0C1310)],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${payload.totalKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: m.sub,
                      // Pickup-near signal (references/*pill* "color only, no
                      // new element"): pickup at/under the driver's cutoff
                      // paints the km green, over paints it red. No pickup
                      // info → default cream.
                      color: switch (payload.pickupIsNear) {
                        true => const Color(0xFF5ECD90),
                        false => const Color(0xFFFF8A7E),
                        null => FoxColors.creamDim,
                      },
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (payload.pricePerHour > 0) ...[
                    SizedBox(width: m.gap),
                    Container(
                        width: 1, height: m.sub, color: const Color(0x52F4EFE1)),
                    SizedBox(width: m.gap),
                    Text(
                      '\$${payload.pricePerHour.toStringAsFixed(0)}/hr',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: m.sub,
                        color: FoxColors.creamDim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _PillMetrics _metrics(PillSize size) => switch (size) {
    PillSize.small => const _PillMetrics(
        padH: 16, padV: 11, gap: 8, rate: 20, unit: 11, sub: 13.5),
    PillSize.medium => const _PillMetrics(
        padH: 18, padV: 12, gap: 10, rate: 22, unit: 12, sub: 15),
    PillSize.large => const _PillMetrics(
        padH: 22, padV: 15, gap: 12, rate: 27, unit: 14, sub: 18),
  };
}

class _PillMetrics {
  final double padH, padV, gap, rate, unit, sub;
  const _PillMetrics({
    required this.padH,
    required this.padV,
    required this.gap,
    required this.rate,
    required this.unit,
    required this.sub,
  });
}
