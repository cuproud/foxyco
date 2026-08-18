import 'package:flutter/material.dart';

/// FoxyCo design tokens — single source of truth.
///
/// Values mirror the reference mockups (references/foxyco_*.html): a warm
/// cream paper base with near-black "receipt/HUD" hero cards, one saturated
/// orange accent, and three fixed verdict colors. Fraunces (serif) carries the
/// big money numbers; Inter carries everything else.

/// Type families. [display] carries the big money numbers and is driver-picked
/// (Settings → Appearance, [MoneyFont]); main.dart / the overlay isolate set it
/// before each theme build, so per-widget `fontFamily: FoxFonts.display`
/// call sites follow without edits. Inter carries everything else.
class FoxFonts {
  const FoxFonts._();
  static String display = 'Inter';
  static const sans = 'Inter';
}

/// Verdict colors — semantic. Always paired with a shape + word in UI so they
/// survive colorblindness and glare (never color alone).
///
/// [good]/[ok]/[bad] VARY with the theme and are repointed by [FoxColors.apply]:
/// the bright on-dark tier is unreadable as text on white (#4FBB7C on white is
/// ~2:1), so light mode swaps in deeper tiers. [goodOnDark]/… stay const at the
/// bright tier for anything that is always on a dark surface — chiefly the
/// overlay pill, which floats over other apps' UI in its own isolate.
/// [goodBg]/… are translucent tint wells behind labels and follow the tier.
class VerdictColors {
  const VerdictColors._();

  // ── The always-bright tier (authored for a black stage) ──────────────────
  static const goodOnDark = Color(0xFF4FBB7C);
  static const okOnDark = Color(0xFFEFB94F);
  static const badOnDark = Color(0xFFEA6D62);
  static const unknownOnDark = Color(0xFF9A9A8D);

  /// Solid graphical fills — segment bars, legend dots — in BOTH modes.
  ///
  /// Only text and thin strokes need the theme-varying tier. A 16dp block of
  /// brand amber reads fine on a white card where amber *text* would not, and
  /// the deep tier turns the segment bar olive-and-maroon (device 2026-07-25).
  static const goodFill = goodOnDark;
  static const okFill = okOnDark;
  static const badFill = badOnDark;

  // ── Deeper tier for ink-on-paper (WCAG AA as text on white) ─────────────
  static const goodOnLight = Color(0xFF1F7A48);
  static const okOnLight = Color(0xFF8A5B00);
  static const badOnLight = Color(0xFFB3271A);
  static const unknownOnLight = Color(0xFF5F6660);

  /// Repointed by [FoxColors.apply]; read these everywhere except the pill.
  static Color good = goodOnDark;
  static Color ok = okOnDark;
  static Color bad = badOnDark;
  static Color unknown = unknownOnDark;

  /// Translucent tint wells (chips, badges). Alpha is heavier on paper — 15%
  /// of a deep hue on white is nearly invisible.
  static Color goodBg = goodOnDark.withValues(alpha: 0.15);
  static Color okBg = okOnDark.withValues(alpha: 0.15);
  static Color badBg = badOnDark.withValues(alpha: 0.15);

  static void _apply(Brightness b) {
    final light = b == Brightness.light;
    good = light ? goodOnLight : goodOnDark;
    ok = light ? okOnLight : okOnDark;
    bad = light ? badOnLight : badOnDark;
    unknown = light ? unknownOnLight : unknownOnDark;
    final wellAlpha = light ? 0.12 : 0.15;
    goodBg = good.withValues(alpha: wellAlpha);
    okBg = ok.withValues(alpha: wellAlpha);
    badBg = bad.withValues(alpha: wellAlpha);
  }
}

/// Every color that CHANGES between light and dark. Only the brand orange, the
/// per-app dots and the always-bright verdict tier stay `const` on [FoxColors].
///
/// Light mode is a full flip, not a chrome-only one (device 2026-07-25: dark
/// "receipt" cards marooned on cream paper read as half-finished). The gradient
/// cards go white-on-paper and the text on them goes to ink, so [cardTop] /
/// [onCard] vary alongside the page chrome. The only thing that stays dark in
/// both modes is the overlay pill — it floats over other apps in its own
/// isolate, where the palette is never applied.
class FoxPalette {
  const FoxPalette({
    required this.bgBase,
    required this.bgSurface,
    required this.bgSurface2,
    required this.border,
    required this.borderSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.uber,
    required this.cardTop,
    required this.cardBottom,
    required this.onCard,
    required this.onCardDim,
    required this.onCardFaint,
    required this.shadowAlpha,
    required this.brightness,
  });

  final Color bgBase;
  final Color bgSurface;
  final Color bgSurface2;
  final Color border;
  final Color borderSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// The hero/receipt card gradient stops (top-left → bottom-right).
  final Color cardTop;
  final Color cardBottom;

  /// Uber's roundel. The only per-app dot that has to vary: Uber's brand is
  /// black-on-white, so the badge is near-white on a dark chip and has to
  /// invert to near-black once the chip goes white (device 2026-07-25: the
  /// roundel and its letter both vanished). Lyft pink and Hopp green are
  /// saturated enough to hold on either.
  final Color uber;

  /// Text drawn ON a gradient card, at three emphasis levels. Alpha-tinting
  /// [onCard] is also how call sites build wells and hairlines inside a card
  /// (`onCard.withValues(alpha: 0.08)`), so these have to be the card's
  /// foreground ink, not the page's.
  final Color onCard;
  final Color onCardDim;
  final Color onCardFaint;

  /// Depth shadows are tuned for a black stage. On cream paper the same alphas
  /// read as grime, so [Shadows] scales them by this.
  final double shadowAlpha;

  final Brightness brightness;

  /// Deep green-black "showroom" (spec M6 §1) — the shipping default.
  static const dark = FoxPalette(
    bgBase: Color(0xFF0C1210), // deep green-black stage
    bgSurface: Color(0xFF161F1A), // cards
    bgSurface2: Color(0xFF1F2A24), // nested chips / wells
    border: Color(0x1FF4EFE1), // 12% cream hairline
    borderSoft: Color(0x14F4EFE1), // 8% cream
    textPrimary: FoxColors.creamConst,
    textSecondary: Color(0x9EF4EFE1), // 62% cream
    textDisabled: Color(0x5CF4EFE1), // 36% cream
    uber: Color(0xFFEDEDED), // near-white on a dark chip
    cardTop: Color(0xFF1C2620), // hero-gradient light stop
    cardBottom: Color(0xFF141A17), // hero-gradient dark stop
    onCard: FoxColors.creamConst,
    onCardDim: Color(0xC6F4EFE1), // ~78% cream
    onCardFaint: Color(0x5CF4EFE1), // 36% cream
    shadowAlpha: 1.0,
    brightness: Brightness.dark,
  );

  /// Daylight mode (device 2026-07-24: the dark theme is unreadable outdoors in
  /// the afternoon). Text alphas are heavier than the dark palette's — the same
  /// 36% that reads as "receded" on black reads as "broken" on paper.
  ///
  /// Cards are a near-flat white gradient rather than pure white: a hairline of
  /// warmth at the bottom keeps them from vanishing into the paper, and the two
  /// stops let the same `LinearGradient` call sites work in both modes.
  static const light = FoxPalette(
    bgBase: Color(0xFFF4F1E8), // warm cream paper
    bgSurface: Color(0xFFFFFFFF), // cards
    bgSurface2: Color(0xFFEDE9DD), // nested chips / wells
    border: Color(0x24101815), // 14% ink hairline
    borderSoft: Color(0x14101815), // 8% ink
    textPrimary: Color(0xFF101815), // deep green-black ink
    textSecondary: Color(0xA6101815), // 65% ink
    textDisabled: Color(0x7A101815), // 48% ink
    uber: Color(0xFF111111), // Uber's brand black on a white chip
    cardTop: Color(0xFFFFFFFF),
    cardBottom: Color(0xFFF7F4EC),
    onCard: Color(0xFF101815), // same ink as the page
    onCardDim: Color(0xA6101815), // 65% ink
    onCardFaint: Color(0x7A101815), // 48% ink
    // 0.5, not 0.35: the layered shadows are individually much fainter than the
    // single blur they replaced, so paper can carry more of them before they
    // read as grime — and at 0.35 the light theme had no depth at all.
    shadowAlpha: 0.5,
    brightness: Brightness.light,
  );
}

/// Surface + text colors.
///
/// Every theme-varying token is `static` (not `const`) and reassigned by
/// [apply]; the same trick [FoxFonts.display] already uses for the driver-picked
/// money font. `main.dart` applies the palette before building the theme, so
/// plain `FoxColors.textPrimary` call sites follow the switch with no edits.
///
/// Naming, now that BOTH the page and the cards flip (2026-07-25):
/// - [textPrimary]/[textSecondary]/[textDisabled] — text on the PAGE.
/// - [cream]/[creamDim]/[creamFaint] — text on a gradient CARD, and (alpha-
///   tinted) the wells and hairlines inside one. The names are historical: in
///   light mode they resolve to ink, not cream.
/// - [ink]/[inkSoft] — the card gradient stops. Also historical: in light mode
///   they resolve to white.
///
/// Only [brandFox], the per-app dots and [creamConst] are truly fixed.
class FoxColors {
  const FoxColors._();

  /// The palette currently applied. Read it for [FoxPalette.brightness] /
  /// [FoxPalette.shadowAlpha]; the individual colors are mirrored below.
  static FoxPalette palette = FoxPalette.dark;

  /// Point every varying token at [p]. Call before building the theme.
  static void apply(FoxPalette p) {
    palette = p;
    bgBase = p.bgBase;
    bgSurface = p.bgSurface;
    bgSurface2 = p.bgSurface2;
    border = p.border;
    borderSoft = p.borderSoft;
    textPrimary = p.textPrimary;
    textSecondary = p.textSecondary;
    textDisabled = p.textDisabled;
    inkSoft = p.cardTop;
    ink = p.cardBottom;
    cream = p.onCard;
    creamDim = p.onCardDim;
    creamFaint = p.onCardFaint;
    uber = p.uber;
    VerdictColors._apply(p.brightness);
  }

  static Color bgBase = FoxPalette.dark.bgBase;
  static Color bgSurface = FoxPalette.dark.bgSurface;
  static Color bgSurface2 = FoxPalette.dark.bgSurface2;
  static Color border = FoxPalette.dark.border;
  static Color borderSoft = FoxPalette.dark.borderSoft;

  static Color textPrimary = FoxPalette.dark.textPrimary;
  static Color textSecondary = FoxPalette.dark.textSecondary;
  static Color textDisabled = FoxPalette.dark.textDisabled;

  // ── Gradient-card interior (varies; see the class doc on the names) ──────
  static Color ink = FoxPalette.dark.cardBottom;
  static Color inkSoft = FoxPalette.dark.cardTop;
  static Color cream = FoxPalette.dark.onCard;
  static Color creamDim = FoxPalette.dark.onCardDim;
  static Color creamFaint = FoxPalette.dark.onCardFaint;

  /// The literal cream, const in both modes. For the few surfaces that are
  /// always dark whatever the theme: the splash, and the overlay pill.
  static const creamConst = Color(0xFFF4EFE1);

  /// Foxy orange — accents, logo, primary actions. One accent per screen.
  static const brandFox = Color(0xFFFF5A36);
  static const brandFoxDeep = Color(0xFFB93A1E);
  static const brandFoxSoft = Color(0x33FF5A36); // translucent tint

  // Per-app dot colors. [uber] varies (see FoxPalette.uber); the saturated two
  // hold on either surface.
  static Color uber = FoxPalette.dark.uber;
  static const lyft = Color(0xFFFF37A6);
  static const hopp = Color(0xFF2E7D32);
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

  /// Depth alphas are authored for the black stage and scaled down on paper
  /// (see [FoxPalette.shadowAlpha]) — at full strength they look like dirt.
  static Color _depth(double alpha) =>
      Colors.black.withValues(alpha: alpha * FoxColors.palette.shadowAlpha);

  // Every elevation is a PAIR (device 2026-07-25: "everything is flat"). One
  // blur can't do both jobs — a tight dark contact shadow pins the card to the
  // surface, a wide faint ambient one lifts it off the page. A single mid blur
  // reads as a gray halo, which is what one-layer elevation always looks like.

  static List<BoxShadow> get card => [
    BoxShadow(color: _depth(0.16), blurRadius: 3, offset: const Offset(0, 1)),
    BoxShadow(color: _depth(0.20), blurRadius: 18, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(color: _depth(0.10), blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: _depth(0.10), blurRadius: 8, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> get hero => [
    BoxShadow(color: _depth(0.22), blurRadius: 6, offset: const Offset(0, 2)),
    BoxShadow(color: _depth(0.26), blurRadius: 28, offset: const Offset(0, 14)),
    BoxShadow(color: _depth(0.16), blurRadius: 56, offset: const Offset(0, 30)),
  ];

  /// Orange glow behind active/live elements.
  static List<BoxShadow> get glow => [
    BoxShadow(
      color: FoxColors.brandFox.withValues(alpha: 0.45),
      blurRadius: 18,
    ),
    BoxShadow(
      color: FoxColors.brandFox.withValues(alpha: 0.20),
      blurRadius: 40,
    ),
  ];

  /// Softer orange glow.
  static List<BoxShadow> get glowSoft => [
    BoxShadow(
      color: FoxColors.brandFox.withValues(alpha: 0.25),
      blurRadius: 12,
    ),
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
