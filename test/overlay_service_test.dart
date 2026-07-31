import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/overlay_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('x-slayer/overlay_channel');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hide does not call closeOverlay when no window is active', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isOverlayActive') return false;
          throw StateError('inactive overlay must not receive ${call.method}');
        });

    await const OverlayService().hide();

    expect(calls, ['isOverlayActive']);
  });
}
