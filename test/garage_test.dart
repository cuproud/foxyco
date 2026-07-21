import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';

Vehicle _v(String id, {FuelType fuel = FuelType.gas}) => Vehicle(
  id: id,
  make: 'Toyota',
  model: 'Camry',
  year: '2022',
  plate: 'ABC-123',
  colorValue: 0xFFC62828,
  bodyType: VehicleType.sedan,
  fuelType: fuel,
);

void main() {
  test('json round-trip preserves everything', () {
    final g = Garage(
      vehicles: [
        _v('a', fuel: FuelType.ev),
        _v('b'),
      ],
      activeId: 'b',
    );
    final back = Garage.fromJson(g.toJson());
    expect(back.vehicles.length, 2);
    expect(back.activeId, 'b');
    expect(back.vehicles.first.fuelType, FuelType.ev);
    expect(back.vehicles.first.bodyType, VehicleType.sedan);
    expect(back.active!.id, 'b');
  });

  test('active falls back to first vehicle when activeId is stale', () {
    final g = Garage(vehicles: [_v('a')], activeId: 'gone');
    expect(g.active!.id, 'a');
  });

  test('empty garage has null active', () {
    expect(Garage.empty.active, isNull);
  });

  test('remove active vehicle activates the next one', () {
    final g = Garage(vehicles: [_v('a'), _v('b')], activeId: 'a').remove('a');
    expect(g.vehicles.length, 1);
    expect(g.active!.id, 'b');
    expect(g.activeId, 'b');
  });

  test('remove last vehicle leaves an empty garage', () {
    final g = Garage(vehicles: [_v('a')], activeId: 'a').remove('a');
    expect(g.vehicles, isEmpty);
    expect(g.active, isNull);
  });

  test('upsert replaces by id, appends when new', () {
    var g = Garage(vehicles: [_v('a')], activeId: 'a');
    g = g.upsert(_v('a', fuel: FuelType.hybrid));
    expect(g.vehicles.length, 1);
    expect(g.vehicles.first.fuelType, FuelType.hybrid);
    g = g.upsert(_v('b'));
    expect(g.vehicles.length, 2);
  });

  test('legacy profile with vehicle info migrates to one-vehicle garage', () {
    const p = DriverProfile(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleModel: 'Camry',
      vehicleYear: '2022',
      licensePlate: 'ABC-123',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.sedan,
    );
    final g = Garage.fromLegacyProfile(p);
    expect(g.vehicles.length, 1);
    expect(g.active!.make, 'Toyota');
    expect(g.active!.fuelType, FuelType.gas); // migration default
    expect(g.active!.colorValue, 0xFFC62828);
  });

  test('legacy profile with only a name migrates to an EMPTY garage', () {
    const p = DriverProfile(name: 'Vamsi');
    expect(Garage.fromLegacyProfile(p).vehicles, isEmpty);
  });

  test('vehicleLine formats like the old profile line', () {
    expect(_v('a').vehicleLine, 'Red 2022 Toyota Camry · ABC-123');
  });

  test('fromJson tolerates garbage', () {
    final g = Garage.fromJson({'vehicles': 'nope', 'activeId': 3});
    expect(g.vehicles, isEmpty);
  });
}
