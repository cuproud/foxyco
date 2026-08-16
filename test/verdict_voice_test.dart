import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/verdict_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('foxyco/voice');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('voice uses verdict-only phrases and a shared cooldown', () async {
    final spoken = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'speak') {
            spoken.add(
              (call.arguments as Map<dynamic, dynamic>)['text'] as String,
            );
          }
          return null;
        });

    final voice = VerdictVoice();
    await voice.preview(Verdict.good);
    await voice.preview(Verdict.ok);
    await voice.speak(Verdict.good, 120);
    await voice.speak(Verdict.ok, 120);

    expect(spoken, ['Good offer', 'Okay offer', 'Good offer']);
  });
}
