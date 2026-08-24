import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/bubble_style.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/services/accessibility/accessibility_watcher.dart';
import 'package:foxyco/services/overlay_service.dart';
import 'package:foxyco/services/ocr/ocr_capture.dart';
import 'package:foxyco/services/session_log.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/overlay/overlay_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _DelayedWatcher extends _FakeWatcher {
  final checks = <Completer<bool>>[];

  @override
  Future<bool> isEnabled() {
    final check = Completer<bool>();
    checks.add(check);
    return check.future;
  }
}

class _MemorySessionLog extends SessionLog {
  @override
  List<SessionSummary> build() => const [];

  @override
  void record(SessionSummary session) => state = [session, ...state];
}

class _FakeOcrCapture extends OcrCapture {
  var stops = 0;

  @override
  Future<void> stop() async => stops++;
}

class _FakeOverlayService implements OverlayService {
  _FakeOverlayService({this.active = false});
  final bool active;
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showOffer(
    OverlayPayload p, {
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {}
  @override
  Stream<OverlayAction> get actionStream => const Stream.empty();
  @override
  Future<bool> isActive() async => active;
  @override
  Future<void> startWatching({
    bool paused = false,
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {}
  @override
  Future<void> update(OverlayPayload p) async {}
  @override
  Future<void> setPaused(bool paused) async {}
  @override
  Future<void> setBubbleStyle(BubbleStyle style) async {}
  @override
  Future<void> clearPill() async {}
  @override
  Future<void> hide() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a surviving overlay restores the active session after restart',
    () async {
      final started = DateTime.now().subtract(const Duration(minutes: 12));
      SharedPreferences.setMockInitialValues({
        'foxyco.active_session_started_at.v1': started.millisecondsSinceEpoch,
      });
      final watcher = _FakeWatcher();
      final container = ProviderContainer(
        overrides: [
          accessibilityWatcherProvider.overrideWithValue(watcher),
          overlayServiceProvider.overrideWithValue(
            _FakeOverlayService(active: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(watcher.status.close);

      container.read(dashboardProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(dashboardProvider).status, WatchStatus.watching);
      expect(
        container.read(dashboardProvider.notifier).liveSince,
        DateTime.fromMillisecondsSinceEpoch(started.millisecondsSinceEpoch),
      );
    },
  );

  test('mid-shift accessibility revoke flips the dashboard to blocked '
      '(and re-grant lands on stopped, not auto-watching)', () async {
    final watcher = _FakeWatcher();
    final container = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(_FakeOverlayService()),
        sessionLogProvider.overrideWith(_MemorySessionLog.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watcher.status.close);

    await container.read(dashboardProvider.notifier).refreshPermissions();
    // Once real grants resolve, boot is stopped (spec M5 §4 — manual start).
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
    container.read(dashboardProvider.notifier).startMonitoring();
    container.read(dashboardProvider.notifier).liveSince = DateTime.now()
        .subtract(const Duration(minutes: 2));
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
    expect(container.read(dashboardProvider.notifier).liveSince, isNull);
    expect(container.read(sessionLogProvider), hasLength(1));

    // Re-granted out-of-band → back to stopped, awaiting an explicit start
    // (the revoke ended the shift; we never auto-resume watching).
    watcher.enabled = true;
    watcher.status.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
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

    await container.read(dashboardProvider.notifier).refreshPermissions();
    // Pause only exists on a running watch — start first.
    container.read(dashboardProvider.notifier).startMonitoring();
    container.read(dashboardProvider.notifier).togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.paused);

    // A status blip with everything still granted must NOT un-pause.
    watcher.status.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(dashboardProvider).status, WatchStatus.paused);
  });

  test('unexpected overlay shutdown also stops OCR capture', () async {
    final watcher = _FakeWatcher();
    final ocr = _FakeOcrCapture();
    final container = ProviderContainer(
      overrides: [
        accessibilityWatcherProvider.overrideWithValue(watcher),
        overlayServiceProvider.overrideWithValue(_FakeOverlayService()),
        ocrCaptureProvider.overrideWithValue(ocr),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watcher.status.close);

    final dashboard = container.read(dashboardProvider.notifier);
    await dashboard.refreshPermissions();
    dashboard.startMonitoring();
    await dashboard.refreshPermissions();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
    expect(ocr.stops, 1);
  });

  test(
    'permission change during a check queues one final-state check',
    () async {
      final watcher = _DelayedWatcher();
      final container = ProviderContainer(
        overrides: [
          accessibilityWatcherProvider.overrideWithValue(watcher),
          overlayServiceProvider.overrideWithValue(_FakeOverlayService()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(watcher.status.close);
      final dashboard = container.read(dashboardProvider.notifier);

      final refresh = dashboard.refreshPermissions();
      while (watcher.checks.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      unawaited(dashboard.refreshPermissions());
      watcher.checks.first.complete(true);
      while (watcher.checks.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      watcher.checks.last.complete(false);
      await refresh;

      expect(container.read(dashboardProvider).status, WatchStatus.blocked);
      expect(
        container.read(dashboardProvider).permissions.accessibilityGranted,
        isFalse,
      );
    },
  );
}
