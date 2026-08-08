import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';

import 'config/overlay_config.dart';

class FlutterAccessibilityService {
  FlutterAccessibilityService._();

  static const MethodChannel _methodChannel =
      MethodChannel('x-slayer/accessibility_channel');
  static const EventChannel _eventChannel =
      EventChannel('x-slayer/accessibility_event');
  static const EventChannel _statusChannel =
      EventChannel('x-slayer/accessibility_status');
  static Stream<AccessibilityEvent>? _stream;
  static Stream<bool>? _statusStream;

  /// stream the incoming Accessibility events
  static Stream<AccessibilityEvent> get accessStream {
    if (Platform.isAndroid) {
      _stream ??=
          _eventChannel.receiveBroadcastStream().map<AccessibilityEvent>(
                (event) => AccessibilityEvent.fromMap(jsonDecode(event)),
              );
      return _stream!;
    }
    throw Exception("Accessibility API exclusively available on Android!");
  }

  /// Emits `true` when the accessibility service is enabled and `false` when
  /// it is disabled. The current state is always emitted immediately on listen.
  static Stream<bool> get onAccessibilityServiceStatusChanged {
    if (Platform.isAndroid) {
      _statusStream ??= _statusChannel
          .receiveBroadcastStream()
          .map<bool>((event) => event as bool);
      return _statusStream!;
    }
    throw Exception("Accessibility API exclusively available on Android!");
  }

  /// request accessibility permission
  /// it will open the accessibility settings page and return `true` once the permission granted.
  static Future<bool> requestAccessibilityPermission() async {
    try {
      return await _methodChannel
          .invokeMethod('requestAccessibilityPermission');
    } on PlatformException catch (error) {
      log("$error");
      return Future.value(false);
    }
  }

  /// check if accessibility permission is enabled
  static Future<bool> isAccessibilityPermissionEnabled() async {
    try {
      return await _methodChannel
          .invokeMethod('isAccessibilityPermissionEnabled');
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  /// Show an overlay window of `TYPE_ACCESSIBILITY_OVERLAY`
  ///
  /// Don't forget to add the overlay entrypoint in the main level.
  ///
  /// example:
  /// ```dart
  /// @pragma("vm:entry-point")
  /// void accessibilityOverlay() {
  ///   runApp(
  ///     const MaterialApp(
  ///       debugShowCheckedModeBanner: false,
  ///       home: BlockingOverlay(),
  ///     ),
  ///   );
  /// }
  /// ```
  static Future<bool> showOverlayWindow([
    OverlayConfig config = const OverlayConfig(),
  ]) async {
    try {
      return await _methodChannel.invokeMethod<bool?>(
            'showOverlayWindow',
            config.toJson(),
          ) ??
          false;
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  /// Hide the overlay window
  static Future<bool> hideOverlayWindow() async {
    try {
      return await _methodChannel.invokeMethod<bool?>('hideOverlayWindow') ??
          false;
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }
}
