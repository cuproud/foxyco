import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/overlay_action.dart';
import 'package:foxyco/domain/overlay_payload.dart';
import 'package:foxyco/domain/offer.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/billing/entitlement.dart';
import 'package:foxyco/services/overlay_service.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/overlay/overlay_controller.dart';

/// Fake standing in for the real plugin wrapper — records calls, no platform.
class _FakeOverlayService implements OverlayService {
  bool granted;
  bool requestSucceeds;
  int requestCount = 0;
  final List<OverlayPayload> shown = [];
  final List<bool> pausedCalls = [];
  bool hidden = false;
  bool watchingStarted = false;
  Completer<void>? startGate;
  final List<String> operations = [];
  bool throwOnShow = false;
  int clearCount = 0;

  /// Drives actionStream so tests can inject bubble gestures.
  final _actions = StreamController<OverlayAction>.broadcast();

  _FakeOverlayService({this.granted = true, this.requestSucceeds = true});

  void emitAction(OverlayAction a) => _actions.add(a);

  @override
  Stream<OverlayAction> get actionStream => _actions.stream;

  @override
  Future<bool> isPermissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    if (requestSucceeds) granted = true;
    return granted;
  }

  @override
  Future<bool> isActive() async => shown.isNotEmpty;

  @override
  Future<void> startWatching({bool paused = false}) async {
    operations.add('start-begin');
    await startGate?.future;
    watchingStarted = true;
    pausedCalls.add(paused);
    operations.add('start-end');
  }

  @override
  Future<void> showOffer(OverlayPayload payload) async {
    if (throwOnShow) throw StateError('show failed');
    shown.add(payload);
  }

  @override
  Future<void> update(OverlayPayload payload) async => shown.add(payload);

  @override
  Future<void> setPaused(bool paused) async => pausedCalls.add(paused);

  @override
  Future<void> clearPill() async => clearCount++;

  @override
  Future<void> hide() async {
    operations.add('hide');
    hidden = true;
  }
}

class _MutableAccessStore extends AccessStore {
  @override
  Access build() => const Access(entitled: false, source: AccessSource.none);

  @override
  Future<void> tick() async {}

  void setAccess(Access next) => state = next;
}

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

ProviderContainer _containerWith(_FakeOverlayService fake) {
  final c = ProviderContainer(
    overrides: [
      overlayServiceProvider.overrideWithValue(fake),
      dashboardProvider.overrideWith(_GrantedDashboardController.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('shows a pill when permission already granted', () async {
    final fake = _FakeOverlayService(granted: true);
    final c = _containerWith(fake);

    final ok = await c.read(overlayControllerProvider.notifier).simulateOffer();

    expect(ok, isTrue);
    expect(fake.shown, hasLength(1));
    expect(fake.requestCount, 0); // already granted → no settings trip
  });

  test('requests permission first when missing, then shows', () async {
    final fake = _FakeOverlayService(granted: false, requestSucceeds: true);
    final c = _containerWith(fake);

    final ok = await c.read(overlayControllerProvider.notifier).simulateOffer();

    expect(ok, isTrue);
    expect(fake.requestCount, 1);
    expect(fake.shown, hasLength(1));
  });

  test('returns false and shows nothing when permission denied', () async {
    final fake = _FakeOverlayService(granted: false, requestSucceeds: false);
    final c = _containerWith(fake);

    final ok = await c.read(overlayControllerProvider.notifier).simulateOffer();

    expect(ok, isFalse);
    expect(fake.shown, isEmpty);
  });

  test('contains native show failures', () async {
    final fake = _FakeOverlayService()..throwOnShow = true;
    final c = _containerWith(fake);

    final ok = await c.read(overlayControllerProvider.notifier).simulateOffer();

    expect(ok, isFalse);
    expect(fake.shown, isEmpty);
  });

  test('entitlement transition clears a visible locked pill', () async {
    final fake = _FakeOverlayService();
    final c = ProviderContainer(
      overrides: [
        overlayServiceProvider.overrideWithValue(fake),
        accessProvider.overrideWith(_MutableAccessStore.new),
        dashboardProvider.overrideWith(_GrantedDashboardController.new),
      ],
    );
    addTearDown(c.dispose);
    c.read(overlayControllerProvider);
    c.read(dashboardProvider.notifier).startMonitoring();
    await c
        .read(overlayControllerProvider.notifier)
        .showFromOffer(
          const Offer(
            platform: GigPlatform.uber,
            payout: 10,
            pickupKm: 2,
            dropoffKm: 8,
          ),
          Verdict.ok,
        );
    expect(fake.shown.single.entitled, isFalse);

    (c.read(accessProvider.notifier) as _MutableAccessStore).setAccess(
      const Access(entitled: true, source: AccessSource.purchase),
    );
    await Future<void>.delayed(Duration.zero);

    expect(fake.clearCount, 1);
  });

  test('rotates through GOOD/OK/BAD samples on repeat taps', () async {
    final fake = _FakeOverlayService(granted: true);
    final c = _containerWith(fake);
    final ctrl = c.read(overlayControllerProvider.notifier);

    await ctrl.simulateOffer();
    await ctrl.simulateOffer();
    await ctrl.simulateOffer();

    final verdicts = fake.shown.map((p) => p.verdict).toSet();
    expect(verdicts.length, 3); // three distinct verdicts seen
  });

  test('hide() closes the overlay', () async {
    final fake = _FakeOverlayService();
    final c = _containerWith(fake);
    await c.read(overlayControllerProvider.notifier).hide();
    expect(fake.hidden, isTrue);
  });

  test(
    'bubble long-press takes the dashboard offline + closes the overlay',
    () async {
      final fake = _FakeOverlayService();
      final c = _containerWith(fake);
      // Instantiate the controller so it subscribes to the action stream.
      c.read(overlayControllerProvider);
      c.read(dashboardProvider.notifier).startMonitoring();
      expect(c.read(dashboardProvider).status, WatchStatus.watching);

      fake.emitAction(OverlayAction.togglePause);
      await Future<void>.delayed(Duration.zero); // let the stream deliver

      expect(c.read(dashboardProvider).status, WatchStatus.paused);
      expect(fake.hidden, isTrue); // offline tears the bubble down, not dims it
    },
  );

  test('brings the overlay up when monitoring starts (req 11)', () async {
    final fake = _FakeOverlayService();
    final c = _containerWith(fake);

    // Boot lands stopped (spec M5 §4): instantiating the controller must NOT
    // raise the bubble; pressing Start must.
    c.read(overlayControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(fake.watchingStarted, isFalse);

    c.read(dashboardProvider.notifier).startMonitoring();
    await Future<void>.delayed(Duration.zero);

    expect(fake.watchingStarted, isTrue);
    expect(fake.pausedCalls, contains(false)); // came up un-paused
  });

  test('going offline closes the overlay; going online re-raises it', () async {
    final fake = _FakeOverlayService();
    final c = _containerWith(fake);
    c.read(overlayControllerProvider);
    c.read(dashboardProvider.notifier).startMonitoring();
    await Future<void>.delayed(Duration.zero);

    c.read(dashboardProvider.notifier).togglePause(); // → offline
    await Future<void>.delayed(Duration.zero);
    expect(fake.hidden, isTrue); // overlay torn down, not dimmed

    c.read(dashboardProvider.notifier).togglePause(); // → online
    await Future<void>.delayed(Duration.zero);
    expect(fake.watchingStarted, isTrue); // bubble re-raised
    expect(fake.pausedCalls.last, isFalse); // ...un-paused
  });

  test('stopped status hides the overlay', () async {
    final fake = _FakeOverlayService();
    final c = _containerWith(fake);
    c.read(overlayControllerProvider);
    c.read(dashboardProvider.notifier).startMonitoring();
    await Future<void>.delayed(Duration.zero);
    expect(fake.watchingStarted, isTrue);

    c.read(dashboardProvider.notifier).stopMonitoring();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(dashboardProvider).status, WatchStatus.stopped);
    expect(fake.hidden, isTrue);
  });

  test('rapid start then stop cannot leave a late ghost bubble', () async {
    final fake = _FakeOverlayService()..startGate = Completer<void>();
    final c = _containerWith(fake);
    c.read(overlayControllerProvider);
    await Future<void>.delayed(Duration.zero); // initial stopped → hide
    fake.operations.clear();
    fake.hidden = false;

    c.read(dashboardProvider.notifier).startMonitoring();
    await Future<void>.delayed(Duration.zero); // start enters its gate
    c.read(dashboardProvider.notifier).stopMonitoring();
    await Future<void>.delayed(Duration.zero);

    expect(fake.operations, ['start-begin']);
    fake.startGate!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fake.operations, ['start-begin', 'start-end', 'hide']);
    expect(fake.hidden, isTrue);
    expect(c.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test(
    'dropping the bubble (stopWatching action) stops the dashboard',
    () async {
      final fake = _FakeOverlayService();
      final c = _containerWith(fake);
      c.read(overlayControllerProvider);
      c.read(dashboardProvider.notifier).startMonitoring();
      expect(c.read(dashboardProvider).status, WatchStatus.watching);

      fake.emitAction(OverlayAction.stopWatching);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(dashboardProvider).status, WatchStatus.stopped);
    },
  );
}
