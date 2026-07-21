import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/ui/theme/platform_badge.dart';

void main() {
  testWidgets('PlatformBadge shows platform initial', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              PlatformBadge(platform: GigPlatform.uber),
              PlatformBadge(platform: GigPlatform.lyft),
              PlatformBadge(platform: GigPlatform.hopp),
            ],
          ),
        ),
      ),
    );
    expect(find.text('U'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
  });

  testWidgets('PlatformBadge dims when inactive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlatformBadge(platform: GigPlatform.uber, active: false),
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('U'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1.0));
  });
}
