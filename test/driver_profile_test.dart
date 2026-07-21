import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';

void main() {
  test('empty profile has no name and empty vehicle line', () {
    expect(DriverProfile.empty.hasName, isFalse);
    expect(DriverProfile.empty.vehicleLine, isEmpty);
  });

  test('json round-trip preserves every field', () {
    final p = DriverProfile.empty.copyWith(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleModel: 'Camry',
      vehicleYear: '2022',
      licensePlate: 'ABC-123',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.suv,
    );
    final back = DriverProfile.fromJson(p.toJson());
    expect(back.name, 'Vamsi');
    expect(back.vehicleMake, 'Toyota');
    expect(back.vehicleModel, 'Camry');
    expect(back.vehicleYear, '2022');
    expect(back.licensePlate, 'ABC-123');
    expect(back.vehicleColor, 0xFFC62828);
    expect(back.vehicleType, VehicleType.suv);
  });

  test('fromJson tolerates missing/garbage fields', () {
    final p = DriverProfile.fromJson(const {'vehicleType': 'spaceship'});
    expect(p.name, isEmpty);
    expect(p.vehicleType, VehicleType.sedan);
  });

  test('vehicleLine skips empty parts cleanly', () {
    expect(
      DriverProfile.empty
          .copyWith(vehicleMake: 'Toyota', vehicleColor: 0xFFC62828)
          .vehicleLine,
      'Red Toyota',
    );
    expect(
      DriverProfile.empty
          .copyWith(vehicleMake: 'Honda', licensePlate: 'XYZ')
          .vehicleLine,
      contains('· XYZ'),
    );
  });
}
