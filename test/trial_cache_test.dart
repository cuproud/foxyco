import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/trial_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedTrialStore extends TrialStore {
  final loadPreferences = Completer<SharedPreferences>();
  var _firstRead = true;

  @override
  Future<SharedPreferences> preferences() {
    if (_firstRead) {
      _firstRead = false;
      return loadPreferences.future;
    }
    return SharedPreferences.getInstance();
  }

  void simulateServerState(TrialState next) => setResolvedState(next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pre-trial snapshot removes every previous account value', () async {
    SharedPreferences.setMockInitialValues({
      'foxyco.trial.startedAt.v1': DateTime.utc(
        2026,
        7,
        1,
      ).millisecondsSinceEpoch,
      'foxyco.trial.verifiedAt.v1': DateTime.utc(
        2026,
        7,
        2,
      ).millisecondsSinceEpoch,
      'foxyco.trial.email.v1': 'old@example.com',
    });
    final prefs = await SharedPreferences.getInstance();

    await replaceTrialCache(
      prefs,
      const TrialState(phase: TrialPhase.preTrial),
    );

    expect(prefs.getInt('foxyco.trial.startedAt.v1'), isNull);
    expect(prefs.getInt('foxyco.trial.verifiedAt.v1'), isNull);
    expect(prefs.getString('foxyco.trial.email.v1'), isNull);
  });

  test('slow startup cache cannot overwrite newer server state', () async {
    SharedPreferences.setMockInitialValues({
      'foxyco.trial.email.v1': 'old@example.com',
    });
    final container = ProviderContainer(
      overrides: [trialProvider.overrideWith(_DelayedTrialStore.new)],
    );
    addTearDown(container.dispose);
    container.read(trialProvider);
    final trial = container.read(trialProvider.notifier) as _DelayedTrialStore;
    final server = TrialState.from(
      startedAt: DateTime.now().toUtc(),
      verifiedAt: DateTime.now().toUtc(),
      email: 'new@example.com',
      now: DateTime.now().toUtc(),
    );

    trial.simulateServerState(server);
    trial.loadPreferences.complete(await SharedPreferences.getInstance());
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(container.read(trialProvider).email, 'new@example.com');
  });
}
