import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/ui/home/home_screen.dart';

void main() {
  testWidgets('Home dashboard renders its core sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );

    // App title + the hero status card + section headers.
    expect(find.text('FoxyCo'), findsOneWidget);
    expect(find.text('Watching for offers'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('LAST OFFER'), findsOneWidget);

    // Tally labels present.
    expect(find.text('GOOD'), findsWidgets);
  });

  testWidgets('Pause button toggles the status', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Watching for offers'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });
}
