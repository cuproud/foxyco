import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/theme/tokens.dart';

/// Guard against the light-theme bug class that shipped on 2026-07-25: a token
/// pair that reads fine in one palette and goes invisible in the other (cream
/// text on cream paper). Every foreground token is checked against the surface
/// it is defined to sit on, in BOTH palettes.
///
/// Ratios are WCAG 2.x contrast; 4.5 is AA body text, 3.0 is AA large/graphical.
void main() {
  /// Composite [fg] (possibly translucent) over [bg], then measure.
  double ratio(Color fg, Color bg) {
    final a = fg.a;
    final flat = Color.from(
      alpha: 1,
      red: fg.r * a + bg.r * (1 - a),
      green: fg.g * a + bg.g * (1 - a),
      blue: fg.b * a + bg.b * (1 - a),
    );
    final l1 = _luminance(flat), l2 = _luminance(bg);
    final hi = math.max(l1, l2), lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  for (final (name, p) in [
    ('dark', FoxPalette.dark),
    ('light', FoxPalette.light),
  ]) {
    group('$name palette', () {
      test('page text reads on every page surface', () {
        for (final surface in [p.bgBase, p.bgSurface, p.bgSurface2]) {
          expect(
            ratio(p.textPrimary, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name textPrimary on $surface',
          );
          expect(
            ratio(p.textSecondary, surface),
            greaterThanOrEqualTo(3.0),
            reason: '$name textSecondary on $surface',
          );
        }
      });

      test('card text reads on the card gradient', () {
        for (final stop in [p.cardTop, p.cardBottom]) {
          expect(
            ratio(p.onCard, stop),
            greaterThanOrEqualTo(4.5),
            reason: '$name onCard on $stop',
          );
          expect(
            ratio(p.onCardDim, stop),
            greaterThanOrEqualTo(3.0),
            reason: '$name onCardDim on $stop',
          );
        }
      });

      test('verdict text reads on cards and page', () {
        FoxColors.apply(p);
        for (final surface in [p.bgSurface, p.cardTop]) {
          for (final (label, c) in [
            ('good', VerdictColors.good),
            ('ok', VerdictColors.ok),
            ('bad', VerdictColors.bad),
          ]) {
            expect(
              ratio(c, surface),
              greaterThanOrEqualTo(3.0),
              reason: '$name verdict $label on $surface',
            );
          }
        }
        FoxColors.apply(FoxPalette.dark);
      });

      test('the Uber roundel reads on cards and page', () {
        // Uber's brand is black-on-white, so this badge is the one per-app dot
        // that has to invert with the theme (device 2026-07-25: near-white
        // roundel + white letter on a white card = nothing at all).
        for (final surface in [p.bgSurface, p.cardTop, p.bgBase]) {
          expect(
            ratio(p.uber, surface),
            greaterThanOrEqualTo(3.0),
            reason: '$name uber roundel on $surface',
          );
        }
        // …and PlatformBadge's letter has to contrast the roundel itself.
        final letter = p.uber.computeLuminance() > 0.5
            ? const Color(0xFF111111)
            : const Color(0xFFFFFFFF);
        expect(ratio(letter, p.uber), greaterThanOrEqualTo(4.5));
      });

      test('the card is distinguishable from the page behind it', () {
        expect(
          ratio(p.cardTop, p.bgBase),
          greaterThan(1.02),
          reason: '$name card would vanish into the page',
        );
      });
    });
  }

  test('the always-dark tokens stay dark after a light apply', () {
    // The overlay pill and the splash keep painting on a dark stage whatever
    // the driver picked, so these must NOT follow the palette.
    FoxColors.apply(FoxPalette.light);
    expect(FoxColors.creamConst, const Color(0xFFF4EFE1));
    expect(VerdictColors.goodOnDark, const Color(0xFF4FBB7C));
    expect(
      ratio(FoxColors.creamConst, FoxPalette.dark.bgBase),
      greaterThanOrEqualTo(4.5),
    );
    FoxColors.apply(FoxPalette.dark);
  });
}

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}
