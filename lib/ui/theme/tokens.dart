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
/// After M6 the whole app is dark, so the bright on-dark tier IS the primary
/// tier; the old names alias it so call-sites survive. [goodBg]/… are
/// translucent tint wells behind labels.
class VerdictColors {
  const VerdictColors._();

  static const good = Color(0xFF4FBB7C);
  static const ok = Color(0xFFEFB94F);
  static const bad = Color(0xFFEA6D62);
  static const unknown = Color(0xFF9A9A8D);

  // Aliases kept so existing call-sites compile unchanged.
  static const goodOnDark = good;
  static const okOnDark = ok;
  static const badOnDark = bad;

  // Translucent tint wells (chips, badges) on dark surfaces.
  static const goodBg = Color(0x264FBB7C);
  static const okBg = Color(0x26EFB94F);
  static const badBg = Color(0x26EA6D62);
}

/// Surface + text colors — deep green-black "showroom" direction (spec M6 §1).
/// Base is darker than the old ink; cards sit lighter on top; cream is now the
/// primary text color everywhere.
class FoxColors {
  const FoxColors._();

  static const bgBase = Color(0xFF0C1210); // deep green-black stage
  static const bgSurface = Color(0xFF161F1A); // cards
  static const bgSurface2 = Color(0xFF1F2A24); // nested chips / wells
  static const border = Color(0x1FF4EFE1); // 12% cream hairline
  static const borderSoft = Color(0x14F4EFE1); // 8% cream

  static const ink = Color(0xFF141A17); // hero-gradient dark stop (kept)
  static const inkSoft = Color(0xFF1C2620); // hero-gradient light stop (kept)
  static const cream = Color(0xFFF4EFE1); // primary text
  static const creamDim = Color(0xC6F4EFE1); // ~0.78 alpha cream

  static const textPrimary = cream;
  static const textSecondary = Color(0x9EF4EFE1); // 62% cream
  static const textDisabled = Color(0x5CF4EFE1); // 36% cream

  /// Foxy orange — accents, logo, primary actions. One accent per screen.
  static const brandFox = Color(0xFFFF5A36);
  static const brandFoxDeep = Color(0xFFB93A1E);
  static const brandFoxSoft = Color(0x33FF5A36); // translucent tint on dark

  // Per-app dot colors. Uber flips light — #111 is invisible on dark.
  static const uber = Color(0xFFEDEDED);
  static const lyft = Color(0xFFFF37A6);
  static const hopp = Color(0xFF4FA3E8);
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

/// Elevation on dark = black depth shadows + an orange glow treatment
/// (spec M6 §1) used behind active/live elements.
class Shadows {
  const Shadows._();

  static List<BoxShadow> get card => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5)),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get hero => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 26, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 44, offset: const Offset(0, 26)),
  ];

  /// Orange glow behind active/live elements.
  static List<BoxShadow> get glow => [
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.45), blurRadius: 18),
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.20), blurRadius: 40),
  ];

  /// Softer orange glow.
  static List<BoxShadow> get glowSoft => [
    BoxShadow(color: FoxColors.brandFox.withValues(alpha: 0.25), blurRadius: 12),
  ];
}

/// Motion durations + curves (spec M6 §8).
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const morph = Duration(milliseconds: 300);
  static const count = Duration(milliseconds: 400);
  static const stagger = Duration(milliseconds: 35);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}
