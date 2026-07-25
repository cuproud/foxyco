import 'package:flutter/material.dart';

import 'tokens.dart';

/// Round −/+ nudge button, for landing a numeric control on an exact value.
///
/// Sliders are fine for "roughly here" and bad at "exactly $1.35" (device
/// 2026-07-25), so every slider gets a pair of these flanking it. Shared by the
/// History minimum-fare row and the verdict-threshold sliders in Settings.
///
/// Colors are card-relative ([FoxColors.cream] resolves to ink in light mode),
/// so it reads correctly wherever it lands. Pass [onTap] as null at a range end
/// to dim it out.
class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.glyph,
    required this.onTap,
    this.semanticLabel,
  });

  /// '−' or '+'. Use the real minus sign, not a hyphen — it optically matches
  /// the plus.
  final String glyph;

  final VoidCallback? onTap;

  /// Screen-reader label; the glyph alone reads as punctuation.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // 48dp hit area around the 30dp visual (a11y minimum).
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: FoxColors.cream.withValues(alpha: enabled ? 0.08 : 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: FoxColors.cream.withValues(
                    alpha: enabled ? 0.2 : 0.08,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                glyph,
                style: TextStyle(
                  color: FoxColors.cream.withValues(alpha: enabled ? 1 : 0.3),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
