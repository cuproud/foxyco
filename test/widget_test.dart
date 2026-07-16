import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/ui/home/home_screen.dart';

void main() {
  // The dashboard is a tall scroll; give the test a tall viewport so the
  // lazy ListView builds every section (hero + ticket) at once.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Home dashboard renders its core sections', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );

    // Brand bar + the hero status + today's tally + the last-offer ticket.
    expect(find.text('FoxyCo'), findsOneWidget);
    expect(find.text('On the prowl'), findsOneWidget);
    expect(find.text('offers seen today'), findsOneWidget);
    expect(find.text('LAST OFFER'), findsOneWidget);

    // Off-device the offer log is empty — the ticket shows its empty state.
    expect(find.text('No offers yet'), findsOneWidget);
  });

  testWidgets('Stop / Go Live toggles the status', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('On the prowl'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('Off duty'), findsOneWidget); // hero status
    expect(find.text('Go Live'), findsOneWidget); // button flipped
    expect(find.text('Off'), findsOneWidget); // brand-bar live pill
  });
}
