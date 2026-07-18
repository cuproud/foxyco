import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// FoxyCo Material 3 theme — dark "showroom" direction (spec M6 §1).
///
/// Deep green-black surfaces with black depth shadows and an orange glow on
/// live elements. Inter is the base UI face; Fraunces is used per-widget for
/// the big money numbers. Cream is the primary text color throughout.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: FoxColors.bgBase,
      onSurface: FoxColors.textPrimary,
      surfaceContainerHighest: FoxColors.bgSurface,
      primary: FoxColors.brandFox,
      onPrimary: Colors.white,
      outline: FoxColors.border,
      secondary: FoxColors.brandFox,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: FoxFonts.sans,
      scaffoldBackgroundColor: FoxColors.bgBase,
      splashColor: FoxColors.brandFoxSoft,
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
        foregroundColor: FoxColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: FoxColors.bgBase,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FoxColors.bgSurface2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: const BorderSide(color: FoxColors.brandFox, width: 1.5),
        ),
        hintStyle: const TextStyle(color: FoxColors.textSecondary),
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
        color: FoxColors.textPrimary,
        fontFeatures: tabular,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: FoxColors.textPrimary,
        fontFeatures: tabular,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontFamily: FoxFonts.display,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: FoxColors.textPrimary,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: FoxColors.textPrimary,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 13.5,
        color: FoxColors.textPrimary,
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
