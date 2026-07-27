import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/theme/car_hero.dart';

/// The car is two images and one animated value; the only thing that can quietly
/// break is which back layer gets painted. Pin that.
void main() {
  Future<void> pumpCar(
    WidgetTester tester, {
    required double glow,
    required bool onDark,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 360,
          child: CarHero(glow: glow, onDark: onDark),
        ),
      ),
    ),
  );

  List<String> assetsOf(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((i) => (i.image as ResizeImage).imageProvider as AssetImage)
      .map((a) => a.assetName)
      .toList();

  testWidgets('back layer follows onDark', (tester) async {
    await pumpCar(tester, glow: 1, onDark: true);
    expect(assetsOf(tester), [
      'assets/car/foxy_car_glow_dark.png',
      CarHero.coreAsset,
    ]);

    await pumpCar(tester, glow: 1, onDark: false);
    expect(assetsOf(tester), [
      'assets/car/foxy_car_shadow_light.png',
      CarHero.coreAsset,
    ]);
  });

  testWidgets('an invisible back layer is not built at all', (tester) async {
    await pumpCar(tester, glow: 0, onDark: true);
    expect(assetsOf(tester), [CarHero.coreAsset]);
  });
}
