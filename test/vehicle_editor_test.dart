import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/garage.dart';
import 'package:foxyco/ui/settings/garage_controller.dart';
import 'package:foxyco/ui/settings/vehicle_editor_screen.dart';
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

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles.length, 1);
    expect(container.read(garageProvider).active!.make, 'Honda');
  });

  testWidgets('editing an existing vehicle seeds fields; delete confirms', (
    tester,
  ) async {
    _tall(tester);
    const existing = Vehicle(id: 'e1', make: 'Kia', model: 'EV6');
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

    await tester.tap(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(garageProvider).vehicles, isEmpty);
  });
}
