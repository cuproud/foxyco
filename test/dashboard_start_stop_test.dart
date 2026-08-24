import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/ocr/ocr_capture.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GrantedDashboardController extends DashboardController {
  @override
  DashboardState build() => const DashboardState(
    status: WatchStatus.stopped,
    permissions: PermissionStatus(
      overlayGranted: true,
      accessibilityGranted: true,
    ),
  );
}

class _FakeOcrCapture extends OcrCapture {
  var starts = 0;
  var stops = 0;
  var startResult = true;

  @override
  Future<bool> start() async {
    starts++;
    return startResult;
  }

  @override
  Future<void> stop() async => stops++;
}

ProviderContainer _grantedContainer([_FakeOcrCapture? ocr]) =>
    ProviderContainer(
      overrides: [
        dashboardProvider.overrideWith(_GrantedDashboardController.new),
        if (ocr != null) ocrCaptureProvider.overrideWithValue(ocr),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('boots blocked until real permissions resolve', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(dashboardProvider).status, WatchStatus.blocked);
    container.read(dashboardProvider.notifier).startMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.blocked);
  });

  test('startMonitoring → watching; stopMonitoring → stopped', () {
    final container = _grantedContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.watching);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('active session anchor is saved and cleared with monitoring', () async {
    final container = _grantedContainer();
    addTearDown(container.dispose);
    final dashboard = container.read(dashboardProvider.notifier);

    await dashboard.startMonitoring();
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('foxyco.active_session_started_at.v1'), isNotNull);

    dashboard.stopMonitoring();
    await Future<void>.delayed(Duration.zero);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('foxyco.active_session_started_at.v1'), isNull);
  });

  test('pause layers on top of running; stop from paused works', () {
    final container = _grantedContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    c.togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.paused);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('togglePause is a no-op while stopped', () {
    final container = _grantedContainer();
    addTearDown(container.dispose);
    container.read(dashboardProvider.notifier).togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('unavailable OCR still keeps Accessibility watching', () async {
    final ocr = _FakeOcrCapture()..startResult = false;
    final container = _grantedContainer(ocr);
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setOcrEnabled(true);

    await container.read(dashboardProvider.notifier).startMonitoring();

    expect(ocr.starts, 1);
    expect(container.read(dashboardProvider).status, WatchStatus.watching);
  });

  test(
    'OCR readiness initializes and cancellation follows monitoring',
    () async {
      final ocr = _FakeOcrCapture();
      final container = _grantedContainer(ocr);
      addTearDown(container.dispose);
      container.read(settingsProvider.notifier).setOcrEnabled(true);

      final dashboard = container.read(dashboardProvider.notifier);
      await dashboard.startMonitoring();
      await dashboard.startMonitoring();
      expect(ocr.starts, 1);
      dashboard.stopMonitoring();
      await Future<void>.delayed(Duration.zero);
      expect(ocr.stops, 1);
    },
  );

  test('pausing immediately stops OCR capture', () async {
    final ocr = _FakeOcrCapture();
    final container = _grantedContainer(ocr);
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setOcrEnabled(true);

    await container.read(dashboardProvider.notifier).startMonitoring();
    container.read(dashboardProvider.notifier).togglePause();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(dashboardProvider).status, WatchStatus.paused);
    expect(ocr.stops, 1);
  });

  test('turning OCR off cancels pending OCR', () async {
    final ocr = _FakeOcrCapture();
    final container = _grantedContainer(ocr);
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider.notifier);
    settings.setOcrEnabled(true);
    settings.setOcrEnabled(false);
    await Future<void>.delayed(Duration.zero);

    expect(ocr.stops, 1);
  });
}
