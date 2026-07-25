import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_skin.dart';
import 'package:foxyco/domain/fox_settings.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:foxyco/ui/theme/tokens.dart';

void main() {
  test('defaults to dark', () {
    expect(FoxSettings.defaults.skin, AppSkin.dark);
  });

  test('round-trips through json', () {
    final s = FoxSettings.defaults.copyWith(skin: AppSkin.light);
    expect(FoxSettings.fromJson(s.toJson()).skin, AppSkin.light);
  });

  test('old blobs without skin fall back to dark', () {
    final j = FoxSettings.defaults.toJson()..remove('skin');
    expect(FoxSettings.fromJson(j).skin, AppSkin.dark);
  });

  test('unknown persisted name falls back to dark', () {
    final j = FoxSettings.defaults.toJson()..['skin'] = 'neon';
    expect(FoxSettings.fromJson(j).skin, AppSkin.dark);
  });

  // The static-token trick only works if building a theme repoints FoxColors;
  // if apply() ever stops running the whole app silently stays dark.
  test('building a theme applies its palette to the static tokens', () {
    AppTheme.of(FoxPalette.light);
    expect(FoxColors.bgBase, FoxPalette.light.bgBase);
    expect(FoxColors.palette.brightness, Brightness.light);

    AppTheme.of(FoxPalette.dark);
    expect(FoxColors.bgBase, FoxPalette.dark.bgBase);
    expect(FoxColors.palette.brightness, Brightness.dark);
  });

  test('depth shadows scale down on paper', () {
    AppTheme.of(FoxPalette.dark);
    final onBlack = Shadows.hero.first.color.a;
    AppTheme.of(FoxPalette.light);
    expect(Shadows.hero.first.color.a, lessThan(onBlack));
    AppTheme.of(FoxPalette.dark); // leave the default applied for other tests
  });
}
