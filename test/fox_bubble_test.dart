import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/overlay/fox_bubble.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('tap and long-press fire their callbacks', (tester) async {
    var tapped = false;
    var longPressed = false;

    await tester.pumpWidget(
      _host(
        FoxBubble(
          paused: false,
          onTap: () => tapped = true,
          onLongPress: () => longPressed = true,
        ),
      ),
    );

    await tester.tap(find.byType(FoxBubble));
    await tester.longPress(find.byType(FoxBubble));

    expect(tapped, isTrue);
    expect(longPressed, isTrue);
  });

  testWidgets('paused dims the bubble', (tester) async {
    await tester.pumpWidget(_host(const FoxBubble(paused: true)));

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(FoxBubble),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1.0)); // muted when not watching
  });

  testWidgets('active bubble is fully opaque', (tester) async {
    await tester.pumpWidget(_host(const FoxBubble(paused: false)));

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(FoxBubble),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1.0);
  });
}
