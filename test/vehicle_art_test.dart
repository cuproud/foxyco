import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/theme/vehicle_art.dart';

void main() {
  for (final body in VehicleType.values) {
    testWidgets('renders $body without exceptions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: VehicleArt(
              bodyType: body,
              color: const Color(0xFFC62828),
              fuelType: FuelType.ev,
              width: 220,
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is VehicleArtPainter,
        ),
        findsOneWidget,
      );
    });
  }

  test('shouldRepaint only on visual change', () {
    const a = VehicleArtPainter(
      bodyType: VehicleType.sedan,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    const same = VehicleArtPainter(
      bodyType: VehicleType.sedan,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    const diff = VehicleArtPainter(
      bodyType: VehicleType.suv,
      color: Color(0xFFC62828),
      fuelType: FuelType.gas,
    );
    expect(a.shouldRepaint(same), isFalse);
    expect(a.shouldRepaint(diff), isTrue);
  });
}
