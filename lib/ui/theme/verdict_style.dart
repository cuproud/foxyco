import 'package:flutter/material.dart';

import '../../domain/verdict.dart';
import 'tokens.dart';

/// Presentation for a [Verdict]: color + shape-coded icon + word.
///
/// Always used together so a verdict is never conveyed by color alone
/// (colorblind-safe, glare-safe). [color] reads on cream/paper, [colorOnDark]
/// on the near-black hero card + overlay pill, [bg] is the soft tint chip.
class VerdictStyle {
  final Color color;
  final Color colorOnDark;
  final Color bg;
  final IconData icon;
  final String label;

  const VerdictStyle._(
    this.color,
    this.colorOnDark,
    this.bg,
    this.icon,
    this.label,
  );

  static VerdictStyle of(Verdict v) => switch (v) {
    // ● filled = GOOD, ◐ half = OK, ○ ring = BAD, ? = unknown
    Verdict.good => const VerdictStyle._(
      VerdictColors.good,
      VerdictColors.goodOnDark,
      VerdictColors.goodBg,
      Icons.circle,
      'GOOD',
    ),
    Verdict.ok => const VerdictStyle._(
      VerdictColors.ok,
      VerdictColors.okOnDark,
      VerdictColors.okBg,
      Icons.contrast,
      'OK',
    ),
    Verdict.bad => const VerdictStyle._(
      VerdictColors.bad,
      VerdictColors.badOnDark,
      VerdictColors.badBg,
      Icons.circle_outlined,
      'BAD',
    ),
    Verdict.unknown => const VerdictStyle._(
      VerdictColors.unknown,
      VerdictColors.unknown,
      FoxColors.borderSoft,
      Icons.help_outline,
      '—',
    ),
  };
}
