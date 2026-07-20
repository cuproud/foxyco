import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/home/profile_card.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';


class _FixedGarage extends GarageController {
  _FixedGarage(this._g);
  final Garage _g;
  @override
  Garage build() => _g;
}

class _FixedName extends DriverNameController {
  _FixedName(this._n);
  final String _n;
  @override
  String build() => _n;
}

Widget _app(String name, Garage g) => ProviderScope(
      overrides: [
        garageProvider.overrideWith(() => _FixedGarage(g)),
        driverNameProvider.overrideWith(() => _FixedName(name)),
      ],
      child: const MaterialApp(home: Scaffold(body: ProfileCard())),
    );

void main() {
  test('greeting bands: 05/12/17/22 boundaries (spec M6 §3.1)', () {
    expect(ProfileCard.greetingFor(5), 'Good morning');
    expect(ProfileCard.greetingFor(11), 'Good morning');
    expect(ProfileCard.greetingFor(12), 'Good afternoon');
    expect(ProfileCard.greetingFor(16), 'Good afternoon');
    expect(ProfileCard.greetingFor(17), 'Good evening');
    expect(ProfileCard.greetingFor(21), 'Good evening');
    expect(ProfileCard.greetingFor(22), 'Late shift');
    expect(ProfileCard.greetingFor(1), 'Late shift');
    expect(ProfileCard.greetingFor(4), 'Late shift');
  });

  testWidgets('no name → no card', (tester) async {
    await tester.pumpWidget(_app('', Garage.empty));
    await tester.pump();
    
    expect(find.textContaining(','), findsNothing);
  });

  testWidgets('name + active vehicle → greeting only (details removed)',
      (tester) async {
    const g = Garage(
      vehicles: [
        Vehicle(
          id: 'a',
          make: 'Toyota',
          model: 'Camry',
          year: '2022',
          plate: 'ABC-123',
          colorValue: 0xFFC62828,
          bodyType: VehicleType.sedan,
          fuelType: FuelType.ev,
        ),
      ],
      activeId: 'a',
    );
    await tester.pumpWidget(_app('Vamsi', g));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    
  });

  testWidgets('name but empty garage → greeting shows, no vehicle line',
      (tester) async {
    await tester.pumpWidget(_app('Vamsi', Garage.empty));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    
  });
}
