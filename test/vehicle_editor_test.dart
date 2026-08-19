import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/driver_profile.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/vehicle_editor_screen.dart';
import 'package:foxyco/ui/theme/vehicle_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => ProviderScope(child: MaterialApp(home: child));

/// The editor is a long ListView; a tall viewport lays out the Save button
/// (which lives at the bottom) without scrolling — same pattern as the
/// settings-screen tests.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Save is disabled until make or model is filled', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.pump();

    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('editor-make')), 'Honda');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
  });

  testWidgets('a non-4-digit year keeps Save disabled', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('editor-make')), 'Honda');
    await tester.enterText(find.byKey(const ValueKey('editor-year')), '12');
    await tester.pump();

    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
  });

  testWidgets('implausible year is rejected and text fields are capped', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.enterText(
      find.byKey(const ValueKey('editor-make')),
      List.filled(40, 'A').join(),
    );
    await tester.enterText(find.byKey(const ValueKey('editor-year')), '1979');
    await tester.pump();

    final make = tester.widget<TextField>(
      find.byKey(const ValueKey('editor-make')),
    );
    expect(make.controller!.text, hasLength(30));
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
  });

  testWidgets('nothing persists until Save, then the vehicle lands active', (
    tester,
  ) async {
    _tall(tester);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const VehicleEditorScreen();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('editor-make')), 'Honda');
    await tester.pump();
    // Draft only — garage untouched before Save (spec M6 §4.3).
    expect(container.read(garageProvider).vehicles, isEmpty);

    await tester.tap(find.byKey(const ValueKey('editor-color')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-body')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SUV'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles.length, 1);
    expect(container.read(garageProvider).active!.make, 'Honda');
    expect(container.read(garageProvider).active!.colorValue, 0xFF1565C0);
    expect(container.read(garageProvider).active!.bodyType, VehicleType.suv);
  });

  testWidgets('editing an existing vehicle seeds fields; delete confirms', (
    tester,
  ) async {
    _tall(tester);
    const existing = Vehicle(
      id: 'e1',
      make: 'Kia',
      model: 'EV6',
      colorValue: 0xFFC62828,
      bodyType: VehicleType.suvComfort,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const VehicleEditorScreen(initial: existing);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await container
        .read(garageProvider.notifier)
        .saveVehicle(existing); // seed garage
    expect(find.widgetWithText(TextField, 'Kia'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('SUV Comfort'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles, isEmpty);
  });

  testWidgets('color and vehicle type are side-by-side', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    final color = tester.getTopLeft(find.byKey(const ValueKey('editor-color')));
    final body = tester.getTopLeft(find.byKey(const ValueKey('editor-body')));
    expect(body.dx, greaterThan(color.dx));
    expect(
      tester.getSize(find.byKey(const ValueKey('editor-color'))).height,
      tester.getSize(find.byKey(const ValueKey('editor-body'))).height,
    );
    expect(find.text('Color · optional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color opens an anchored compact menu and selects a swatch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.tap(find.byKey(const ValueKey('editor-color')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Orange'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vehicle-color-swatch-Red')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem), findsNothing);
    expect(find.text('Red'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle type opens an anchored menu and selects immediately', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_app(const VehicleEditorScreen()));
    await tester.tap(find.byKey(const ValueKey('editor-body')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('E-scooter'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('SUV Comfort'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem), findsNothing);
    expect(find.text('SUV Comfort'), findsOneWidget);
  });

  testWidgets('hybrid fuel badge uses battery and leaf icons', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 240,
          height: 140,
          child: VehicleBadge(
            bodyType: VehicleType.sedan,
            color: Colors.black,
            fuelType: FuelType.hybrid,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.battery_charging_full_rounded), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    expect(find.byIcon(Icons.recycling_rounded), findsNothing);
  });
}
