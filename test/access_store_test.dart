import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/billing_store.dart';
import 'package:foxyco/services/billing/entitlement.dart';
import 'package:foxyco/services/billing/trial_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MutableBillingStore extends BillingStore {
  @override
  UnlockStatus build() => UnlockStatus.notPurchased;

  void setStatus(UnlockStatus next) => state = next;
}

class _MutableTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(phase: TrialPhase.preTrial);

  void setTrial(TrialState next) => state = next;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);

  final void Function() callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

class _ControlledAccessStore extends AccessStore {
  final clocks = <Completer<DateTime>>[];

  @override
  Access build() => Access.resolving;

  @override
  bool get debugUnlocked => false;

  @override
  Future<DateTime> currentTime() {
    final clock = Completer<DateTime>();
    clocks.add(clock);
    return clock.future;
  }
}

class _TimedAccessStore extends AccessStore {
  var now = DateTime.utc(2026, 8, 7, 12);
  _FakeTimer? timer;
  Duration? timerDelay;

  @override
  Access build() => Access.resolving;

  @override
  bool get debugUnlocked => false;

  @override
  Future<DateTime> currentTime() async => now;

  @override
  Timer createTimer(Duration delay, void Function() callback) {
    timerDelay = delay;
    return timer = _FakeTimer(callback);
  }
}

class _DelayedCacheAccessStore extends AccessStore {
  final loadPreferences = Completer<SharedPreferences>();
  var _firstRead = true;
  final now = DateTime.utc(2026, 8, 7, 12);

  @override
  bool get debugUnlocked => false;

  @override
  Future<DateTime> currentTime() async => now;

  @override
  Future<SharedPreferences> preferences() {
    if (_firstRead) {
      _firstRead = false;
      return loadPreferences.future;
    }
    return SharedPreferences.getInstance();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('older derivation cannot overwrite a newer purchase', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        billingProvider.overrideWith(_MutableBillingStore.new),
        trialProvider.overrideWith(_MutableTrialStore.new),
        accessProvider.overrideWith(_ControlledAccessStore.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(accessProvider);
    final access =
        container.read(accessProvider.notifier) as _ControlledAccessStore;
    final billing =
        container.read(billingProvider.notifier) as _MutableBillingStore;

    final older = access.tick();
    billing.setStatus(UnlockStatus.purchased);
    final newer = access.tick();

    expect(access.clocks, hasLength(1));
    access.clocks.first.complete(DateTime.utc(2026, 8, 7, 12));
    while (access.clocks.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    access.clocks.last.complete(DateTime.utc(2026, 8, 7, 12));
    await Future.wait([older, newer]);

    expect(container.read(accessProvider).source, AccessSource.purchase);
  });

  test('store-owned timer expires a trial without a banner mounted', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        billingProvider.overrideWith(_MutableBillingStore.new),
        trialProvider.overrideWith(_MutableTrialStore.new),
        accessProvider.overrideWith(_TimedAccessStore.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(accessProvider);
    final access = container.read(accessProvider.notifier) as _TimedAccessStore;
    final trial = container.read(trialProvider.notifier) as _MutableTrialStore;
    trial.setTrial(
      TrialState.from(
        startedAt: access.now.subtract(
          trialDuration - const Duration(seconds: 30),
        ),
        verifiedAt: access.now,
        email: 'driver@example.com',
        now: access.now,
      ),
    );

    await access.tick();
    expect(container.read(accessProvider).source, AccessSource.trial);
    expect(access.timerDelay, const Duration(seconds: 30));

    access.now = access.now.add(const Duration(seconds: 31));
    access.timer!.fire();
    while (container.read(accessProvider).source == AccessSource.trial) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(accessProvider).entitled, isFalse);
    expect(container.read(accessProvider).source, AccessSource.none);
  });

  test(
    'slow purchase cache cannot replace a newer Play verification',
    () async {
      SharedPreferences.setMockInitialValues({
        'foxyco.unlock.verifiedAt.v1': DateTime.utc(
          2026,
          7,
          1,
        ).millisecondsSinceEpoch,
      });
      final container = ProviderContainer(
        overrides: [
          billingProvider.overrideWith(_MutableBillingStore.new),
          trialProvider.overrideWith(_MutableTrialStore.new),
          accessProvider.overrideWith(_DelayedCacheAccessStore.new),
        ],
      );
      addTearDown(container.dispose);
      container.read(accessProvider);
      final access =
          container.read(accessProvider.notifier) as _DelayedCacheAccessStore;
      final billing =
          container.read(billingProvider.notifier) as _MutableBillingStore;

      billing.setStatus(UnlockStatus.purchased);
      await access.tick();
      access.loadPreferences.complete(await SharedPreferences.getInstance());
      await Future<void>.delayed(const Duration(milliseconds: 1));
      billing.setStatus(UnlockStatus.unknown);
      await access.tick();

      expect(
        container.read(accessProvider).source,
        AccessSource.cachedPurchase,
      );
    },
  );

  test('access stays unresolved until a slow purchase cache loads', () async {
    SharedPreferences.setMockInitialValues({
      'foxyco.unlock.verifiedAt.v1': DateTime.utc(
        2026,
        8,
        7,
        11,
      ).millisecondsSinceEpoch,
    });
    final container = ProviderContainer(
      overrides: [
        billingProvider.overrideWith(_MutableBillingStore.new),
        trialProvider.overrideWith(_MutableTrialStore.new),
        accessProvider.overrideWith(_DelayedCacheAccessStore.new),
      ],
    );
    addTearDown(container.dispose);

    (container.read(billingProvider.notifier) as _MutableBillingStore)
        .setStatus(UnlockStatus.unknown);
    expect(container.read(accessProvider).resolved, isFalse);
    final access =
        container.read(accessProvider.notifier) as _DelayedCacheAccessStore;
    access.loadPreferences.complete(await SharedPreferences.getInstance());
    while (!container.read(accessProvider).resolved) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(accessProvider).source, AccessSource.cachedPurchase);
  });
}
