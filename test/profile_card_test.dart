import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/ui/home/profile_card.dart';
import 'package:foxyco/ui/settings/profile_controller.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(this._p);
  final DriverProfile _p;
  @override
  DriverProfile build() => _p;
}

Widget _app(DriverProfile p) => ProviderScope(
      overrides: [profileProvider.overrideWith(() => _FixedProfile(p))],
      child: const MaterialApp(home: Scaffold(body: ProfileCard())),
    );

void main() {
  testWidgets('no name → no card', (tester) async {
    await tester.pumpWidget(_app(DriverProfile.empty));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is VehiclePainter,
      ),
      findsNothing,
    );
    expect(find.textContaining('Good'), findsNothing);
  });

  testWidgets('named profile → greeting + vehicle line + art', (tester) async {
    final p = DriverProfile.empty.copyWith(
      name: 'Vamsi',
      vehicleMake: 'Toyota',
      vehicleColor: 0xFFC62828,
      vehicleType: VehicleType.sedan,
    );
    await tester.pumpWidget(_app(p));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vamsi'), findsOneWidget);
    expect(find.textContaining('Red Toyota'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is VehiclePainter,
      ),
      findsOneWidget,
    );
  });
}
