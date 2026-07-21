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
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );

    // Brand bar + the hero status + today's tally + the last-offer ticket.
    // Boot lands stopped (spec M5 §4): monitoring waits for an explicit start.
    expect(find.text('FoxyCo'), findsOneWidget);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.textContaining('offers seen'), findsOneWidget);
    expect(find.text('LAST OFFER'), findsOneWidget);

    // Off-device the offer log is empty — the ticket shows its empty state.
    expect(find.textContaining('No offers yet'), findsOneWidget);
  });

  testWidgets('Go live / Stop toggles monitoring', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );

    // Boots stopped with the slide-to-go-live CTA showing.
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Slide to go live'), findsOneWidget);

    // Slide the thumb fully right past the commit threshold → onStart.
    await tester.drag(
      find.byKey(const ValueKey('slide-thumb')),
      const Offset(1080, 0),
    );
    await tester.pump();
    expect(find.text('On the prowl'), findsOneWidget); // hero status
    // 'Live' now shows in both the brand-bar pill and the slide live bar.
    expect(find.text('Live'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('slide-stop-thumb')), findsOneWidget);

    // Slide the stop thumb fully left past the threshold → onStop.
    await tester.drag(
      find.byKey(const ValueKey('slide-stop-thumb')),
      const Offset(-1080, 0),
    );
    await tester.pump();
    expect(find.text('Ready when you are'), findsOneWidget); // fully stopped
    expect(find.text('Slide to go live'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget); // brand-bar live pill
  });
}
