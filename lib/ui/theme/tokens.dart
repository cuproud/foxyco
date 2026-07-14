import 'package:flutter/material.dart';

/// FoxyCo design tokens — single source of truth.
///
/// Values mirror the reference mockups (references/foxyco_*.html): a warm
/// cream paper base with near-black "receipt/HUD" hero cards, one saturated
/// orange accent, and three fixed verdict colors. Fraunces (serif) carries the
/// big money numbers; Inter carries everything else.

/// Type families. Fraunces = display/serif numbers, Inter = UI text.
class FoxFonts {
  const FoxFonts._();
  static const display = 'Fraunces';
  static const sans = 'Inter';
}

/// Verdict colors — semantic, fixed. Always paired with a shape + word in UI
/// so they survive colorblindness and glare (never color alone).
///
/// Two tiers: the saturated [good]/[ok]/[bad] read on cream (paper surfaces),
/// the brighter [goodOnDark]/… read on the near-black hero cards and the
/// overlay pill. [goodBg]/… are the soft tint chips used behind labels.
class VerdictColors {
  const VerdictColors._();

  // On cream / paper
  static const good = Color(0xFF2C6B47);
  static const ok = Color(0xFFD89A2E);
  static const bad = Color(0xFFD2483F);
  static const unknown = Color(0xFF87877A);

  // On near-black hero cards + overlay pill (brighter so they glow)
  static const goodOnDark = Color(0xFF4FBB7C);
  static const okOnDark = Color(0xFFEFB94F);
  static const badOnDark = Color(0xFFEA6D62);

  // Soft tint backgrounds (chips, badges)
  static const goodBg = Color(0xFFE6F1EA);
  static const okBg = Color(0xFFFBF0D9);
  static const badBg = Color(0xFFFAE6E3);
}

/// Surface + text colors (warm cream / paper direction).
class FoxColors {
  const FoxColors._();

  static const bgBase = Color(0xFFF6F3EA); // paper
  static const bgSurface = Color(0xFFFFFEFB); // cards
  static const border = Color(0xFFE9E2D2);
  static const borderSoft = Color(0xFFEFE9DC);

  static const ink = Color(0xFF161F19); // near-black hero + primary text
  static const inkSoft = Color(0xFF26332B);
  static const cream = Color(0xFFF4EFE1); // text/fills on dark
  static const creamDim = Color(0xC6F4EFE1); // ~0.78 alpha cream

  static const textPrimary = ink;
  static const textSecondary = Color(0xFF87877A); // muted
  static const textDisabled = Color(0xFFBBB6A5); // muted-2

  /// Foxy orange — accents, logo, primary buttons only. One accent per screen.
  static const brandFox = Color(0xFFFF5A36);
  static const brandFoxDeep = Color(0xFFB93A1E);
  static const brandFoxSoft = Color(0xFFFFE4D9);

  // Per-app dot colors (history chips)
  static const uber = Color(0xFF111111);
  static const lyft = Color(0xFFFF37A6);
  static const hopp = Color(0xFF2F80C4);
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
  static const hero = 28.0;
  static const card = 20.0;
  static const cardSm = 16.0;
  static const field = 12.0;
}

/// Soft, warm elevation shadows (the mockups lean on layered shadow, not
/// outlines). [hero] is the deep lift under the dark cards + bottom nav.
class Shadows {
  const Shadows._();

  static const _ink = Color(0xFF161F19);

  static List<BoxShadow> get card => [
    BoxShadow(color: _ink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
    BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 1, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get hero => [
    BoxShadow(color: _ink.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 12)),
    BoxShadow(color: _ink.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 26)),
  ];
}

/// Motion durations + curve.
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const count = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}
