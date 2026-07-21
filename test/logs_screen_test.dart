import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/fox_log.dart';
import 'package:foxyco/ui/settings/logs_screen.dart';

void main() {
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
    await tester.tap(find.text('Clear')); // confirm dialog action
    await tester.pumpAndSettle();
    expect(find.textContaining('doomed'), findsNothing);
    expect(find.textContaining('No logs yet'), findsOneWidget);
  });
}
