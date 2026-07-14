import 'package:flutter/material.dart';

import 'tokens.dart';

/// FoxyCo Material 3 theme — warm cream "paper" direction (references/*.html).
///
/// Light, low-glare surfaces with soft layered shadows instead of hard
/// outlines. Inter is the base UI face; Fraunces is used per-widget for the big
/// money numbers. Verdict/hero cards supply their own near-black surfaces.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      surface: FoxColors.bgBase,
      onSurface: FoxColors.ink,
      surfaceContainerHighest: FoxColors.bgSurface,
      primary: FoxColors.brandFox,
      onPrimary: Colors.white,
      outline: FoxColors.border,
      secondary: FoxColors.brandFox,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: FoxFonts.sans,
      scaffoldBackgroundColor: FoxColors.bgBase,
      splashColor: FoxColors.brandFoxSoft.withValues(alpha: 0.4),
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: FoxColors.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
          side: BorderSide(color: FoxColors.borderSoft),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FoxColors.bgBase,
        foregroundColor: FoxColors.ink,
        elevation: 0,
        centerTitle: false,
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
  static TextTheme _textTheme(TextTheme t) {
    const tabular = [FontFeature.tabularFigures()];
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 60,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        color: FoxColors.ink,
        fontFeatures: tabular,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: FoxColors.ink,
        fontFeatures: tabular,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: FoxColors.ink,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: FoxColors.ink,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 13.5,
        color: FoxColors.ink,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: FoxColors.textDisabled,
      ),
    );
  }
}
