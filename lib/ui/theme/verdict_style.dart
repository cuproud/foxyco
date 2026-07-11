import 'package:flutter/material.dart';

import '../../domain/verdict.dart';
import 'tokens.dart';

/// Presentation for a [Verdict]: color + shape-coded icon + word.
///
/// Always used together so a verdict is never conveyed by color alone
/// (colorblind-safe, glare-safe — see docs/UI_DESIGN §7/§8).
class VerdictStyle {
  final Color color;
  final IconData icon;
  final String label;

  const VerdictStyle._(this.color, this.icon, this.label);

  static VerdictStyle of(Verdict v) => switch (v) {
    // ● filled = GOOD, ◐ half = OK, ○ ring = BAD, ? = unknown
    Verdict.good => const VerdictStyle._(
      VerdictColors.good,
      Icons.circle,
      'GOOD',
    ),
    Verdict.ok => const VerdictStyle._(
      VerdictColors.ok,
      Icons.contrast, // half-filled disc
      'OK',
    ),
    Verdict.bad => const VerdictStyle._(
      VerdictColors.bad,
      Icons.circle_outlined,
      'BAD',
    ),
    Verdict.unknown => const VerdictStyle._(
      VerdictColors.unknown,
      Icons.help_outline,
      '—',
    ),
  };
}
