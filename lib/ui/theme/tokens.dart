import 'package:flutter/material.dart';

/// FoxyCo design tokens — single source of truth.
///
/// Values mirror docs/UI_DESIGN.md §3. The M5 visual lock is a value swap here,
/// not a widget rewrite. Direction: Kinetic HUD (near-black, one saturated
/// verdict color per screen).

/// Verdict colors — semantic, fixed. Always paired with a shape + word in UI
/// so they survive colorblindness and glare (never color alone).
class VerdictColors {
  const VerdictColors._();

  static const good = Color(0xFF2ED573); // green  ● GOOD
  static const ok = Color(0xFFFFB020); //  amber  ◐ OK
  static const bad = Color(0xFFFF4757); //  red    ○ BAD
  static const unknown = Color(0xFF8895A7); // grey ? — (low parse confidence)
}

/// Surface + text colors (dark-first / OLED-friendly).
class FoxColors {
  const FoxColors._();

  static const bgBase = Color(0xFF0B0E11);
  static const bgSurface = Color(0xFF151A1F);
  static const bgSurfaceHigh = Color(0xFF1D242B);
  static const outline = Color(0xFF2A333C);

  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFF9AA7B4);
  static const textDisabled = Color(0xFF5A6673);

  /// Foxy orange — accents, logo, primary buttons only. One accent per screen.
  static const brandFox = Color(0xFFFF7A1A);
}

/// Spacing scale (4 dp base).
class Gap {
  const Gap._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Corner radii.
class Radii {
  const Radii._();

  static const pill = 999.0;
  static const card = 20.0;
  static const field = 12.0;
}

/// Motion durations + curve.
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const count = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}
