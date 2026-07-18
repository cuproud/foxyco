import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted garage.v1 when present', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.prefsKey: jsonEncode(
        const Garage(
          vehicles: [Vehicle(id: 'x', make: 'Kia')],
          activeId: 'x',
        ).toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    expect(container.read(garageProvider).active!.make, 'Kia');
  });

  test('migrates legacy profile.v1 into garage.v1 exactly once', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.legacyKey: jsonEncode(
        const DriverProfile(name: 'Vamsi', vehicleMake: 'Toyota').toJson(),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    final g = container.read(garageProvider);
    expect(g.vehicles.length, 1);
    expect(g.active!.make, 'Toyota');
    expect(g.active!.fuelType, FuelType.gas);
    // Migration persisted — garage.v1 now exists, legacy key untouched.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GarageController.prefsKey), isNotNull);
    expect(prefs.getString(GarageController.legacyKey), isNotNull);
  });

  test('corrupt garage.v1 fails soft to empty', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.prefsKey: 'not json{{{',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    expect(container.read(garageProvider).vehicles, isEmpty);
  });

  test('saveVehicle persists and first vehicle becomes active', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(garageProvider);
    await _settle();
    await container
        .read(garageProvider.notifier)
        .saveVehicle(const Vehicle(id: 'n1', make: 'Honda'));
    expect(container.read(garageProvider).active!.id, 'n1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(GarageController.prefsKey), contains('Honda'));
  });

  test('deleteVehicle of active activates next; last delete empties', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(garageProvider.notifier);
    await _settle();
    await c.saveVehicle(const Vehicle(id: 'a', make: 'A'));
    await c.saveVehicle(const Vehicle(id: 'b', make: 'B'));
    await c.deleteVehicle('a');
    expect(container.read(garageProvider).active!.id, 'b');
    await c.deleteVehicle('b');
    expect(container.read(garageProvider).active, isNull);
  });

  test('driver name: loads foxyco.driver.v1, falls back to legacy name', () async {
    SharedPreferences.setMockInitialValues({
      GarageController.legacyKey:
          jsonEncode(const DriverProfile(name: 'Vamsi').toJson()),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(driverNameProvider);
    await _settle();
    expect(container.read(driverNameProvider), 'Vamsi');
    // Seeded into its own key so the legacy blob is never needed again.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverNameController.prefsKey), 'Vamsi');
  });

  test('setName persists', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(driverNameProvider);
    await _settle();
    await container.read(driverNameProvider.notifier).setName('Neo');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverNameController.prefsKey), 'Neo');
  });
}
