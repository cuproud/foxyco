import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/fox_log.dart';
import 'package:foxyco/ui/settings/logs_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late FoxLog log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foxlogui');
    log = FoxLog(dirResolver: () async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget app() => ProviderScope(
    overrides: [foxLogProvider.overrideWithValue(log)],
    child: const MaterialApp(home: LogsScreen()),
  );

  testWidgets('shows log tail', (tester) async {
    log.log('watch', 'hello-line');
    await log.flush();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('hello-line'), findsOneWidget);
  });

  testWidgets('clear empties the view after confirm', (tester) async {
    log.log('watch', 'doomed');
    await log.flush();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('doomed'), findsNothing);
    expect(find.textContaining('No logs yet'), findsOneWidget);
  });

  test('diagnostic copy uses the sensitive native clipboard path', () async {
    const channel = MethodChannel('foxyco/clipboard');
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (value) async {
          call = value;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await setSensitiveClipboard('diagnostic');

    expect(call?.method, 'setSensitiveText');
    expect(call?.arguments, {'text': 'diagnostic'});
  });

  test('email URI targets support and includes the logs', () {
    final uri = logEmailUri('line one\nline two');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'foxyco.tester@gmail.com');
    expect(uri.queryParameters['subject'], 'FoxyCo diagnostic logs');
    expect(uri.queryParameters['body'], 'line one\nline two');
  });

  testWidgets('email action is before copy', (tester) async {
    log.log('watch', 'mail-me');
    await log.flush();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final email = find.byKey(const ValueKey('email-logs'));
    expect(email, findsOneWidget);
    expect(
      tester.getCenter(email).dx,
      lessThan(tester.getCenter(find.byIcon(Icons.copy_rounded)).dx),
    );
  });
}
