import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceHealth {
  const DeviceHealth();

  static const _channel = MethodChannel('foxyco/device_health');

  Future<bool?> batteryUnrestricted() async {
    try {
      return await _channel.invokeMethod<bool>('batteryUnrestricted');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } on PlatformException {
      // App Health stays informative when a vendor removes the settings page.
    } on MissingPluginException {
      // Widget tests and non-Android builds have no native channel.
    }
  }
}

final deviceHealthProvider = Provider<DeviceHealth>(
  (_) => const DeviceHealth(),
);

final batteryUnrestrictedProvider = FutureProvider<bool?>((ref) {
  return ref.read(deviceHealthProvider).batteryUnrestricted();
});
