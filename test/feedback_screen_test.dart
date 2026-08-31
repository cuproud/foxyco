import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/feedback_service.dart';
import 'package:foxyco/ui/settings/feedback_screen.dart';
import 'package:foxyco/ui/settings/settings_screen.dart';
import 'package:foxyco/ui/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeFeedbackPlatform extends FeedbackPlatform {
  FakeFeedbackPlatform({this.picked = const [], this.sendResult = true});

  final List<String> picked;
  final bool sendResult;
  int? requestedLimit;
  FeedbackMessage? sent;

  @override
  Future<FeedbackContext> context() async => const FeedbackContext(
    version: '1.2.3',
    build: '45',
    android: '16',
    device: 'Samsung SM-A546W',
  );

  @override
  Future<List<String>> pickImages(int limit) async {
    requestedLimit = limit;
    return picked.take(limit).toList();
  }

  @override
  Future<bool> send(FeedbackMessage message) async {
    sent = message;
    return sendResult;
  }
}

Widget host(
  FakeFeedbackPlatform platform, {
  FeedbackDraft draft = const FeedbackDraft(),
}) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.dark,
    home: FeedbackScreen(platform: platform, draft: draft),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings opens the lightweight feedback screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SettingsScreen()),
        ),
        GoRoute(
          path: '/feedback',
          builder: (_, _) => FeedbackScreen(platform: FakeFeedbackPlatform()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HELP & SUPPORT'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Help & About'), findsOneWidget);
    expect(find.text('Diagnostic logs'), findsOneWidget);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(find.text('What are you reporting?'), findsOneWidget);
  });

  testWidgets('renders four categories with Problem selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(host(FakeFeedbackPlatform()));

    for (final label in const [
      'Problem',
      'Offer detection',
      'App screen',
      'Other',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Problem'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Include Logs'), findsNothing);
    expect(
      find.text(
        'Screenshots may contain personal or trip information. '
        'Review them before sending.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Offer detection'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Offer detection'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('missed-offer shortcut prefills an actionable report', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(FakeFeedbackPlatform(), draft: const FeedbackDraft.missedOffer()),
    );

    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Offer detection'),
          )
          .selected,
      isTrue,
    );
    expect(find.textContaining('did not show a verdict'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feedback-send')))
          .onPressed,
      isNotNull,
    );
  });

  test('feedback message includes requested diagnostics', () {
    final message = buildFeedbackMessage(
      category: FeedbackCategory.offerDetection,
      description: 'No verdict.',
      context: const FeedbackContext(
        version: '1',
        build: '2',
        android: '16',
        device: 'Phone',
      ),
      diagnostics: 'offer watcher: timeout',
    );

    expect(message.body, contains('Recent FoxyCo diagnostics'));
    expect(message.body, contains('offer watcher: timeout'));
  });

  testWidgets('requires a trimmed description but screenshots stay optional', (
    tester,
  ) async {
    final platform = FakeFeedbackPlatform();
    await tester.pumpWidget(host(platform));
    final send = find.byKey(const Key('feedback-send'));

    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      '   ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      '  The second offer had no pill.  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(platform.sent?.imagePaths, isEmpty);
    expect(platform.sent?.body, contains('The second offer had no pill.'));
    expect(platform.sent?.body, isNot(contains('  The second')));
  });

  testWidgets('limits screenshots to three and allows individual removal', (
    tester,
  ) async {
    final platform = FakeFeedbackPlatform(
      picked: const [
        '/tmp/one.png',
        '/tmp/two.png',
        '/tmp/three.png',
        '/tmp/four.png',
      ],
    );
    await tester.pumpWidget(host(platform));
    await tester.tap(find.text('Other'));
    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      'State survives the picker.',
    );

    await tester.tap(find.byKey(const Key('feedback-add-screenshots')));
    await tester.pumpAndSettle();
    expect(platform.requestedLimit, 3);
    expect(find.text('State survives the picker.'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Other'))
          .selected,
      isTrue,
    );
    expect(find.byTooltip('Remove screenshot'), findsNWidgets(3));
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('feedback-add-screenshots')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('feedback-remove-/tmp/two.png')),
    );
    await tester.pump();
    expect(find.byTooltip('Remove screenshot'), findsNWidgets(2));
  });

  testWidgets('successful email handoff resets the form', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeFeedbackPlatform(picked: const ['/tmp/one.png']);
    await tester.pumpWidget(host(platform));
    await tester.tap(find.text('Other'));
    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      'Reset this after handoff.',
    );
    await tester.tap(find.byKey(const Key('feedback-add-screenshots')));
    await tester.pumpAndSettle();

    final send = find.byKey(const Key('feedback-send'));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('Reset this after handoff.'), findsNothing);
    expect(find.byTooltip('Remove screenshot'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Problem'))
          .selected,
      isTrue,
    );
  });

  testWidgets('builds safe runtime context and handles share failure', (
    tester,
  ) async {
    final platform = FakeFeedbackPlatform(sendResult: false);
    await tester.pumpWidget(host(platform));
    await tester.tap(find.text('App screen'));
    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      'Buttons overlap on my phone.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback-send')));
    await tester.pumpAndSettle();

    final message = platform.sent!;
    expect(message.recipient, feedbackRecipient);
    expect(message.subject, 'FoxyCo v1.2.3 (45) — App screen');
    expect(message.body, contains('Buttons overlap on my phone.'));
    expect(message.body, contains('Version: 1.2.3 (45)'));
    expect(message.body, contains('Android: 16'));
    expect(message.body, contains('Device: Samsung SM-A546W'));
    for (final sensitive in const [
      'foxyco.log',
      'Firebase UID',
      'Google account',
      'exact location',
      'license plate',
      'trip addresses',
    ]) {
      expect(message.body, isNot(contains(sensitive)));
    }
    expect(find.text("Couldn't open an email app."), findsOneWidget);
  });
}
