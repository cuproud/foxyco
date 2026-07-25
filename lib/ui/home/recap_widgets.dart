import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The two building blocks shared by the end-of-shift recap sheet and Home's
/// "Last session" card. They started life private to the sheet; the card was
/// rebuilt on the same layout (device 2026-07-24: "why can't the card look like
/// the recap?") and copies would have drifted the moment either was retouched.

/// The good/ok/bad split as three equal tint-well pills. Count and word are
/// always spelled out, so the verdict colors are never the only signal.
class VerdictSplitPills extends StatelessWidget {
  const VerdictSplitPills({
    super.key,
    required this.good,
    required this.ok,
    required this.bad,
    this.fontSize = 12,
  });

  final int good;
  final int ok;
  final int bad;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _pill(VerdictColors.good, good, 'good'),
      const SizedBox(width: Gap.sm),
      _pill(VerdictColors.ok, ok, 'ok'),
      const SizedBox(width: Gap.sm),
      _pill(VerdictColors.bad, bad, 'bad'),
    ],
  );

  Widget _pill(Color color, int count, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Center(
        // Long labels at a big text scale would otherwise push the row wider
        // than the card (overflow audit 2026-07-25).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: TextStyle(
                    color: FoxColors.cream,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  style: TextStyle(color: color.withValues(alpha: 0.9)),
                ),
              ],
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            maxLines: 1,
          ),
        ),
      ),
    ),
  );
}

/// One labelled stat well — `$1.38` over `BEST $/KM`. Always used in a [Row] of
/// three, hence the [Expanded].
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FoxColors.bgSurface2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: FoxColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: FoxFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FoxColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: FoxColors.textDisabled,
            ),
          ),
        ],
      ),
    ),
  );
}

/// `3 PM` — the busiest-hour label shared by the sheet and the card.
String hourLabel(int h) {
  final ampm = h < 12 ? 'AM' : 'PM';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display $ampm';
}

/// `3h 24m` / `47m` — session duration, shared by the sheet and the card.
String durationLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m}m';
}
