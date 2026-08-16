import 'package:flutter/material.dart';

import '../../domain/overlay_payload.dart';
import '../../domain/verdict.dart';
import '../theme/plasma_border.dart';
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
  const VerdictPill({
    super.key,
    required this.payload,
    this.size,
    this.animate = true,
  });

  final OverlayPayload payload;

  /// Overrides [OverlayPayload.size]. The floating overlay forces
  /// [PillSize.small] to fit the compact draggable window.
  final PillSize? size;

  /// When false the plasma ring renders static (settings preview, tests) —
  /// the orbit loop never settles under pumpAndSettle and buys nothing there.
  final bool animate;

  // Pill-specific verdict fills (references/*pill* :root — a touch deeper than
  // the on-dark seg colors so the light block still reads on a bright map).
  static const _good = Color(0xFF39A96C);
  static const _ok = Color(0xFFE4A83C);
  static const _bad = Color(0xFFE56458);
  static const _unknown = Color(0xFF8895A7);

  /// Sub-label cream. Const because the pill body is dark in both themes.
  static const _dimCream = Color(0xC6F4EFE1);

  Color get _rateColor => switch (payload.verdict) {
    Verdict.good => _good,
    Verdict.ok => _ok,
    Verdict.bad => _bad,
    Verdict.unknown => _unknown,
  };

  @override
  Widget build(BuildContext context) {
    final m = _metrics(size ?? payload.size);
    final rate = '\$${payload.displayRate.toStringAsFixed(2)}';

    // Sheen goes from a lightened verdict color to the base — keeps the block
    // its verdict color (a plain white->transparent gradient would erase it,
    // since a BoxDecoration paints the gradient INSTEAD of `color`).
    final sheenTop = Color.lerp(_rateColor, Colors.white, 0.22)!;

    return Material(
      type: MaterialType.transparency,
      child: PlasmaBorder(
        color: _rateColor,
        animate: animate,
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
                  m.padH + 1,
                  m.padV,
                  m.padH - 1,
                  m.padV,
                ),
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
                      rate,
                      style: TextStyle(
                        fontFamily: FoxFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: m.rate + 1,
                        height: 1,
                        letterSpacing: -0.2,
                        color: const Color(0xFF141C17),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '/${payload.distanceUnit.shortLabel}',
                      style: TextStyle(
                        // Explicit family: the overlay isolate's MaterialApp has
                        // no theme, so an unset family fell back to Roboto and
                        // clashed with the Fraunces figure next to it.
                        fontFamily: FoxFonts.sans,
                        fontWeight: FontWeight.w600,
                        fontSize: m.unit,
                        letterSpacing: 0.2,
                        color: const Color(0xFF141C17).withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              // Dark info block — trip km + $/hr.
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: m.padH,
                  vertical: m.padV,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF203026),
                      Color(0xFF141C17),
                      Color(0xFF0C1310),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${payload.displayDistance.toStringAsFixed(1)} ${payload.distanceUnit.shortLabel}',
                      style: TextStyle(
                        fontFamily: FoxFonts.sans,
                        fontWeight: FontWeight.w700,
                        fontSize: m.sub,
                        // Pickup-near signal (references/*pill* "color only, no
                        // new element"): pickup at/under the driver's cutoff
                        // paints the km green, over paints it red. No pickup
                        // info → default cream.
                        color: switch (payload.pickupIsNear) {
                          true => const Color(0xFF5ECD90),
                          false => const Color(0xFFFF8A7E),
                          // creamConst, not creamDim: the pill is dark in BOTH
                          // themes (it floats over other apps), and the varying
                          // token would go ink here when Settings renders the
                          // sample pill in light mode.
                          null => _dimCream,
                        },
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (payload.pricePerHour > 0) ...[
                      SizedBox(width: m.gap),
                      Container(
                        width: 1,
                        height: m.sub,
                        color: const Color(0x52F4EFE1),
                      ),
                      SizedBox(width: m.gap),
                      Text(
                        '\$${payload.pricePerHour.toStringAsFixed(0)}/hr',
                        style: TextStyle(
                          fontFamily: FoxFonts.sans,
                          fontWeight: FontWeight.w700,
                          fontSize: m.sub,
                          // $/hr tinted by the driver's per-hour cut points
                          // (same "color only, no new element" rule as the
                          // pickup km). No cut points / no time → cream.
                          color: switch (payload.hourVerdict) {
                            Verdict.good => const Color(0xFF5ECD90),
                            Verdict.ok => const Color(0xFFF2C464),
                            Verdict.bad => const Color(0xFFFF8A7E),
                            _ => _dimCream,
                          },
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    if (payload.deliveryCount > 0) ...[
                      SizedBox(width: m.gap),
                      Container(
                        width: 1,
                        height: m.sub,
                        color: const Color(0x52F4EFE1),
                      ),
                      SizedBox(width: m.gap),
                      Text(
                        '${payload.deliveryCount} ${payload.deliveryCount == 1 ? 'delivery' : 'deliveries'}',
                        style: TextStyle(
                          fontFamily: FoxFonts.sans,
                          fontWeight: FontWeight.w700,
                          fontSize: m.sub,
                          color: _dimCream,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Type/padding scale per size. Every field steps by an EQUAL amount from
  /// small→medium→large, so each notch is the same visible jump. The old table
  /// stepped unevenly (rate 20→22→27, +2 then +5) and, worse, all three pills
  /// rendered wider than their overlay window and got clipped rather than
  /// scaled — so Medium and Large drew their text at the same unscaled size and
  /// looked identical on device (2026-08-06). Keep these widths modest: the
  /// window must stay under 360dp to remain draggable (see overlay_entry).
  static _PillMetrics _metrics(PillSize size) => switch (size) {
    PillSize.small => const _PillMetrics(
      padH: 13,
      padV: 9,
      gap: 7,
      rate: 18,
      unit: 10,
      sub: 12.5,
    ),
    PillSize.medium => const _PillMetrics(
      padH: 16,
      padV: 11,
      gap: 9,
      rate: 21,
      unit: 11.5,
      sub: 14.5,
    ),
    PillSize.large => const _PillMetrics(
      padH: 19,
      padV: 13,
      gap: 11,
      rate: 24,
      unit: 13,
      sub: 16.5,
    ),
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
