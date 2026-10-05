import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/settings/about_content.dart';
import 'package:foxyco/ui/settings/about_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

Widget host({bool dark = false, double scale = 1}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: const AboutScreen(),
);

final pageScroll = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> showSearch(WidgetTester tester) async {
  tester.state<ScrollableState>(pageScroll).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    find.byType(TextField),
    200,
    scrollable: pageScroll,
  );
}

void main() {
  testWidgets(
    'search finds answer text, clears and keeps legal links reachable',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.byType(TextField), 'Waze');
      await tester.pumpAndSettle();
      expect(find.text('Why Accessibility?'), findsOneWidget);
      expect(find.text('How are verdicts decided?'), findsNothing);
      await tester.tap(find.text('Why Accessibility?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('content nodes'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Analytics');
      await tester.pumpAndSettle();
      expect(find.text('PRIVACY'), findsOneWidget);
      expect(find.text('What gets stored?'), findsOneWidget);
      expect(find.text('How are verdicts decided?'), findsNothing);

      await tester.enterText(find.byType(TextField), 'no-such-help-entry');
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching help.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        200,
        scrollable: pageScroll,
      );
      expect(find.text('Privacy Policy'), findsOneWidget);
      await showSearch(tester);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('What does FoxyCo do?'), findsOneWidget);
      expect(find.textContaining('No matching help.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final width in [320.0, 360.0]) {
      testWidgets('all answers fit at $width dp, 2x text, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(dark: dark, scale: 2));
        // Search isolates each answer and also checks filter updates do not
        // reuse an unrelated expansion state.
        for (final entry in aboutSections.expand(
          (section) => section.entries,
        )) {
          await showSearch(tester);
          await tester.enterText(find.byType(TextField), entry.question);
          await tester.pumpAndSettle();
          FocusScope.of(tester.element(find.byType(TextField))).unfocus();
          await tester.pumpAndSettle();
          final question = find.descendant(
            of: find.byType(ExpansionTile),
            matching: find.text(entry.question),
          );
          await tester.scrollUntilVisible(
            question,
            200,
            scrollable: pageScroll,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(question);
          await tester.pumpAndSettle();
          await tester.tap(question);
          await tester.pumpAndSettle();
          expect(find.text(entry.answer), findsOneWidget);
          expect(tester.takeException(), isNull, reason: entry.question);
          await showSearch(tester);
        }
      });
    }
  }
}
