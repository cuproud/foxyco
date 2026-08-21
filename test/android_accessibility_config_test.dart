import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/parser/parser_registry.dart';

void main() {
  test('Android accessibility contract stays scoped and system-bindable', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = RegExp(
      r'<service[^>]*AccessibilityListener[^>]*>.*?</service>',
      dotAll: true,
    ).firstMatch(manifest)!.group(0)!;
    expect(service, contains('android.permission.BIND_ACCESSIBILITY_SERVICE'));
    expect(service, contains('android:exported="true"'));

    final config = File(
      'android/app/src/main/res/xml/accessibilityservice.xml',
    ).readAsStringSync();
    final packages = RegExp(
      r'android:packageNames="([^"]+)"',
    ).firstMatch(config)!.group(1)!.split(',').toSet();
    expect(packages, ParserRegistry.watchedPackages.toSet());
    expect(config, isNot(contains('android:canPerformGestures')));
    expect(config, contains('android:canTakeScreenshot="true"'));
    // Required for current Uber accessibilityDataSensitive offer cards. This
    // remains an explicit Play-review decision, not an accidental flag.
    expect(config, contains('android:isAccessibilityTool="true"'));
  });
}
