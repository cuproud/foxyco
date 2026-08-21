import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// FoxyCo Material 3 theme — "showroom" direction (spec M6 §1).
///
/// Two palettes, one build: [FoxPalette.dark] is the deep green-black stage the
/// app shipped with, [FoxPalette.light] the warm cream paper added for daylight
/// (device 2026-07-24). The switch is a full flip — card interiors and verdict
/// hues included — so the only surface that stays dark in both is the overlay
/// pill, which runs in an isolate where the palette is never applied.
///
/// Inter is the base UI face; Fraunces is used per-widget for the big money
/// numbers.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => of(FoxPalette.dark);
  static ThemeData get light => of(FoxPalette.light);

  /// Build the theme for [palette], applying it to [FoxColors] first so the
  /// static token call sites throughout the app resolve to the same mode.
  static ThemeData of(FoxPalette palette) {
    FoxColors.apply(palette);
    final isDark = palette.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: palette.brightness,
      surface: palette.bgBase,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.bgSurface,
      primary: FoxColors.brandFox,
      onPrimary: Colors.white,
      secondary: FoxColors.brandFox,
      onSecondary: Colors.white,
      error: VerdictColors.bad,
      onError: Colors.white,
      outline: palette.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      fontFamily: FoxFonts.sans,
      scaffoldBackgroundColor: palette.bgBase,
      splashColor: FoxColors.brandFoxSoft,
      highlightColor: Colors.transparent,
    );
    final textTheme = _textTheme(base.textTheme, palette);

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: palette.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
          side: BorderSide(color: palette.borderSoft),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bgBase,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        // System bars follow the page, so the status-bar glyphs stay legible
        // against whichever background is behind them.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: palette.bgBase,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.bgSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: FoxColors.brandFox,
        elevation: 0,
        insetPadding: const EdgeInsets.all(Gap.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.cardSm),
          side: const BorderSide(color: FoxColors.brandFox, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.bgSurface2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: BorderSide(color: palette.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.brandFox, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoxColors.brandFox,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Type scale. Fraunces (serif) for display/number headlines, Inter for the
  /// rest. Tabular figures where numbers align.
  static TextTheme _textTheme(TextTheme t, FoxPalette palette) {
    const tabular = [FontFeature.tabularFigures()];
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 60,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        color: palette.textPrimary,
        fontFeatures: tabular,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: palette.textPrimary,
        fontFeatures: tabular,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 13.5,
        color: palette.textPrimary,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: palette.textDisabled,
      ),
    );
  }
}
