import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/services/accessibility/accessibility_watcher.dart';
import 'package:foxyco/services/overlay_service.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/overlay/overlay_controller.dart';

/// Scriptable accessibility grant state + the OS on/off status stream.
class _FakeWatcher extends AccessibilityWatcher {
  bool enabled = true;
  final status = StreamController<bool>.broadcast();
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Stream<bool> get statusChanges => status.stream;
  @override
  Stream<ScreenRead> reads() => const Stream.empty();
}

class _FakeOverlayService implements OverlayService {
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showOffer(OverlayPayload p) async {}
  @override
  Stream<OverlayAction> get actionStream => const Stream.empty();
  @override
  Future<bool> isActive() async => false;
  @override
  Future<void> startWatching({bool paused = false}) async {}
  @override
  Future<void> update(OverlayPayload p) async {}
  @override
  Future<void> setPaused(bool paused) async {}
  @override
  Future<void> clearPill() async {}
  @override
  Future<void> hide() async {}
}

void main() {
  test('mid-shift accessibility revoke flips the dashboard to blocked '
      '(and re-grant restores watching)', () async {
    final watcher = _FakeWatcher();
    final container = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(_FakeOverlayService()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watcher.status.close);

    // Boot: both grants present → watching.
    expect(container.read(dashboardProvider).status, WatchStatus.watching);

    // The OS reports the service turned OFF (user revoked it in settings, or
    // Android killed the service). No app-resume needed.
    watcher.enabled = false;
    watcher.status.add(false);
    await Future<void>.delayed(Duration.zero); // let refreshPermissions run
    expect(container.read(dashboardProvider).status, WatchStatus.blocked);
    expect(
      container.read(dashboardProvider).permissions.accessibilityGranted,
      isFalse,
    );

    // Re-granted out-of-band → straight back to watching.
    watcher.enabled = true;
    watcher.status.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dashboardProvider).status, WatchStatus.watching);
  });

  test('an explicit pause survives a permission re-check', () async {
    final watcher = _FakeWatcher();
    final container = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(_FakeOverlayService()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watcher.status.close);

    container.read(dashboardProvider.notifier).togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.paused);

    // A status blip with everything still granted must NOT un-pause.
    watcher.status.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dashboardProvider).status, WatchStatus.paused);
  });
}
