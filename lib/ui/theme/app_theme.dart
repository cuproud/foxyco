import 'package:flutter/material.dart';

import 'tokens.dart';

/// FoxyCo Material 3 theme — dark-first (Kinetic HUD direction).
///
/// Drivers work nights: dark ships first, light is deferred (M5). Surfaces are
/// flat with a 1 dp outline instead of heavy shadows.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: FoxColors.bgBase,
      onSurface: FoxColors.textPrimary,
      primary: FoxColors.brandFox,
      onPrimary: Colors.black,
      outline: FoxColors.outline,
      secondary: FoxColors.brandFox,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: FoxColors.bgBase,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: FoxColors.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
          side: BorderSide(color: FoxColors.outline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FoxColors.bgBase,
        foregroundColor: FoxColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FoxColors.brandFox,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Type scale from UI_DESIGN §3. Tabular figures where numbers align.
  static TextTheme _textTheme(TextTheme t) {
    const tabular = [FontFeature.tabularFigures()];
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: FoxColors.textPrimary,
        fontFeatures: tabular,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: FoxColors.textPrimary,
        fontFeatures: tabular,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FoxColors.textPrimary,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 14,
        color: FoxColors.textPrimary,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: FoxColors.textSecondary,
      ),
    );
  }
}
