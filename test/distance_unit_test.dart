import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/app_currency.dart';
import 'package:foxyco/domain/distance_unit.dart';
import 'package:foxyco/domain/fox_settings.dart';

void main() {
  test('mile distance and rate conversions round-trip', () {
    expect(DistanceUnit.miles.distanceFromKm(1.609344), closeTo(1, 1e-9));
    expect(DistanceUnit.miles.distanceToKm(1), closeTo(1.609344, 1e-9));
    expect(DistanceUnit.miles.rateFromPerKm(1), closeTo(1.609344, 1e-9));
    expect(DistanceUnit.miles.rateToPerKm(1.609344), closeTo(1, 1e-9));
  });

  test('old settings migrate to Canada-friendly defaults', () {
    final settings = FoxSettings.fromJson(const {});
    expect(settings.distanceUnit, DistanceUnit.kilometres);
    expect(settings.currency, AppCurrency.cad);
  });

  test('unit and currency persist by stable enum name', () {
    final source = FoxSettings.defaults.copyWith(
      distanceUnit: DistanceUnit.miles,
      currency: AppCurrency.usd,
    );
    final restored = FoxSettings.fromJson(source.toJson());
    expect(restored.distanceUnit, DistanceUnit.miles);
    expect(restored.currency, AppCurrency.usd);
  });
}
