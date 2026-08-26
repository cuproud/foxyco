import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/legal/ocr_disclosure.dart';

void main() {
  testWidgets('OCR disclosure states Uber-only memory use before consent', (
    tester,
  ) async {
    var allowed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => allowed = await showOcrDisclosure(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only to the Uber parser'), findsOne);
    expect(find.textContaining('non-Uber offers use its text'), findsOne);
    expect(find.textContaining('never saved or uploaded'), findsOne);

    await tester.tap(find.text('Enable Uber OCR'));
    await tester.pumpAndSettle();
    expect(allowed, isTrue);
  });
}
