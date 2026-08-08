# flutter_accessibility_service — FoxyCo fork

This vendored fork is intentionally read-only. It exposes accessibility status,
screen-event capture, and its own accessibility overlay window. Node actions,
global actions, gesture dispatch, and their native method channels are removed.

FoxyCo's service configuration must keep:

```xml
android:canRetrieveWindowContent="true"
android:canPerformGestures="false"
```

Available APIs:

```dart
await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
await FlutterAccessibilityService.requestAccessibilityPermission();

FlutterAccessibilityService.accessStream.listen((event) {
  // Read the active watched app's accessibility event.
});

await FlutterAccessibilityService.showOverlayWindow();
await FlutterAccessibilityService.hideOverlayWindow();
```

The fork also traverses same-package windows so offer cards rendered in a
separate window reach FoxyCo's parser. Keep behavior changes documented beside
their implementation in `AccessibilityListener.java`.
