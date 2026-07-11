import 'package:flutter/material.dart';

import '../../domain/overlay_payload.dart';
import '../theme/tokens.dart';
import '../theme/verdict_style.dart';

/// The floating verdict pill (docs/OVERLAY §pill).
///
/// One glanceable line: shape-coded verdict dot + word + `km · $payout`. Drawn
/// with the app's own [VerdictStyle] tokens so the overlay and the dashboard
/// speak one visual language. This is a plain widget with no plugin imports —
/// it renders identically in the overlay isolate and in an in-app preview, so
/// we can build and eyeball it without a device.
///
/// Readability first: high-contrast dark capsule, a saturated verdict color,
/// and never color-alone (icon + WORD carry it too — glare/colorblind safe).
class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.payload});

  final OverlayPayload payload;

  @override
  Widget build(BuildContext context) {
    final style = VerdictStyle.of(payload.verdict);
    final m = _metrics(payload.size);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: m.padH, vertical: m.padV),
        decoration: BoxDecoration(
          color: FoxColors.bgSurfaceHigh.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: style.color, width: m.border),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.color, size: m.icon),
            SizedBox(width: m.gap),
            Text(
              style.label,
              style: TextStyle(
                color: style.color,
                fontSize: m.verdictText,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: m.gap),
            // Thin divider keeps the number cluster distinct from the verdict.
            Container(width: 1, height: m.icon, color: FoxColors.outline),
            SizedBox(width: m.gap),
            Text(
              _details(payload),
              style: TextStyle(
                color: FoxColors.textPrimary,
                fontSize: m.detailText,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _details(OverlayPayload p) {
    final km = p.totalKm == p.totalKm.roundToDouble()
        ? p.totalKm.toStringAsFixed(0)
        : p.totalKm.toStringAsFixed(1);
    final pay = p.payout == p.payout.roundToDouble()
        ? p.payout.toStringAsFixed(0)
        : p.payout.toStringAsFixed(2);
    return '$km km · \$$pay';
  }

  static _PillMetrics _metrics(PillSize size) => switch (size) {
        PillSize.small => const _PillMetrics(
            padH: 12, padV: 7, gap: 6, icon: 14,
            verdictText: 13, detailText: 12, border: 1.5),
        PillSize.medium => const _PillMetrics(
            padH: 16, padV: 10, gap: 8, icon: 18,
            verdictText: 16, detailText: 15, border: 2),
        PillSize.large => const _PillMetrics(
            padH: 22, padV: 14, gap: 10, icon: 24,
            verdictText: 21, detailText: 19, border: 2.5),
      };
}

class _PillMetrics {
  final double padH, padV, gap, icon, verdictText, detailText, border;
  const _PillMetrics({
    required this.padH,
    required this.padV,
    required this.gap,
    required this.icon,
    required this.verdictText,
    required this.detailText,
    required this.border,
  });
}
