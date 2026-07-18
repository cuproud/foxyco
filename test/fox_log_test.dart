import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/fox_log.dart';

void main() {
  late Directory tmp;
  late FoxLog log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foxlog');
    log = FoxLog(dirResolver: () async => tmp);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  File logFile() => File('${tmp.path}/logs/foxyco.log');
  File rolled() => File('${tmp.path}/logs/foxyco.log.1');

  test('log appends a tagged timestamped line after flush', () async {
    log.log('watch', 'hello');
    await log.flush();
    final content = logFile().readAsStringSync();
    expect(content, contains('[watch] hello'));
    // ISO-ish timestamp leads the line.
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(content), isTrue);
  });

  test('rotation: exceeding maxBytes rolls to .1 and truncates current',
      () async {
    final small = FoxLog(dirResolver: () async => tmp, maxBytes: 200);
    for (var i = 0; i < 20; i++) {
      small.log('parse', 'x' * 40);
      await small.flush();
    }
    expect(rolled().existsSync(), isTrue);
    expect(logFile().lengthSync(), lessThanOrEqualTo(300));
  });

  test('tail returns end of file', () async {
    log.log('overlay', 'first');
    log.log('overlay', 'last');
    await log.flush();
    final t = await log.tail();
    expect(t, contains('first'));
    expect(t, contains('last'));
  });

  test('clear removes both files', () async {
    log.log('status', 'x');
    await log.flush();
    await log.clear();
    expect(logFile().existsSync(), isFalse);
    expect(rolled().existsSync(), isFalse);
  });

  test('fail-soft: null dir resolver is a silent no-op', () async {
    final noop = FoxLog(dirResolver: () async => null);
    noop.log('error', 'nowhere');
    await noop.flush();
    await noop.clear();
    expect(await noop.tail(), isEmpty); // no throw
  });
}
