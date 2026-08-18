import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';

void main() {
  test('vehicle types keep the original order and labels', () {
    expect(VehicleType.values.map((type) => type.label).toList(), [
      'Sedan',
      'SUV',
      'SUV Comfort',
      'Hatchback',
      'Pickup',
      'Van',
      'EV Van',
      'Premium',
      'Off-road',
      'EV',
      'Bike',
      'E-bike',
      'E-scooter',
      'Motorbike',
    ]);
  });

  test('vehicle type aliases from the selector regression remain readable', () {
    expect(
      DriverProfile.fromJson({'type': 'compactSedan'}).vehicleType,
      VehicleType.hatchback,
    );
    expect(
      DriverProfile.fromJson({'type': 'midSizeSuv'}).vehicleType,
      VehicleType.suvComfort,
    );
    expect(
      DriverProfile.fromJson({'type': 'threeRowSuv'}).vehicleType,
      VehicleType.premium,
    );
  });

  test('original vehicle types retain their bundled art names', () {
    expect(VehicleType.suvComfort.assetName, 'suv_comfort');
    expect(VehicleType.evVan.assetName, 'ev_van');
    expect(VehicleType.offRoad.assetName, 'off_road');
    expect(VehicleType.eBike.assetName, 'e_bike');
    expect(VehicleType.eScooter.assetName, 'e_scooter');
    expect(VehicleType.motorbike.assetName, 'bike');
  });
}
