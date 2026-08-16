import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/overlay_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('x-slayer/overlay_channel');
  const messenger = BasicMessageChannel<Object?>(
    'x-slayer/overlay_messenger',
    JSONMessageCodec(),
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(messenger, null);
  });

  test('hide does not call closeOverlay when no window is active', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isOverlayActive') return false;
          throw StateError('inactive overlay must not receive ${call.method}');
        });

    await OverlayService().hide();

    expect(calls, ['isOverlayActive']);
  });

  test('overlay commands cannot overtake one another', () async {
    final received = <Map<dynamic, dynamic>>[];
    final firstGate = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(messenger, (message) async {
          received.add(message! as Map<dynamic, dynamic>);
          if (received.length == 1) await firstGate.future;
          return message;
        });

    final service = OverlayService();
    final pause = service.setPaused(false);
    await Future<void>.delayed(Duration.zero);
    final clear = service.clearPill();
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    firstGate.complete();
    await Future.wait([pause, clear]);
    expect(received, hasLength(2));
    expect(received.first['paused'], isFalse);
    expect(received.last['clearPill'], isTrue);
  });
}
