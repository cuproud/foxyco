import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/legal/accessibility_disclosure.dart';

void main() {
  testWidgets('requires agreement before opening accessibility settings', (
    tester,
  ) async {
    bool? agreed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              agreed = await showAccessibilityDisclosure(context);
            },
            child: const Text('Fix permissions'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fix permissions'));
    await tester.pumpAndSettle();
    expect(find.text(accessibilityDisclosureTitle), findsOneWidget);
    expect(find.text(accessibilityDisclosureBody), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(agreed, isFalse);

    await tester.tap(find.text('Fix permissions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree & open settings'));
    await tester.pumpAndSettle();
    expect(agreed, isTrue);
  });
}
