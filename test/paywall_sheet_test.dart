import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/services/billing/billing_store.dart';
import 'package:foxyco/services/billing/entitlement.dart';
import 'package:foxyco/services/billing/trial_store.dart';
import 'package:foxyco/ui/paywall/paywall_sheet.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

class _FailedTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(phase: TrialPhase.preTrial);

  @override
  String? get lastStartError => 'auth/operation-not-allowed';

  @override
  Future<TrialStartResult> startTrial() async => TrialStartResult.failed;
}

class _UnavailableBillingStore extends BillingStore {
  @override
  UnlockStatus build() => UnlockStatus.unavailable;
}

class _LockedAccessStore extends AccessStore {
  @override
  Access build() => const Access(entitled: false, source: AccessSource.none);
}

class _StartedTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(phase: TrialPhase.preTrial);

  @override
  Future<TrialStartResult> startTrial() async => TrialStartResult.started;
}

class _UnlockingAccessStore extends AccessStore {
  @override
  Access build() => const Access(entitled: false, source: AccessSource.none);

  @override
  Future<void> refresh({bool sampled = false}) async {
    state = const Access(entitled: true, source: AccessSource.trial);
    // Let the paywall's entitlement listener dismiss the sheet before the
    // explicit trial-success path resumes.
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  testWidgets('trial failure is visible inside the paywall with a safe code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialProvider.overrideWith(_FailedTrialStore.new),
          billingProvider.overrideWith(_UnavailableBillingStore.new),
          accessProvider.overrideWith(_LockedAccessStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPaywall(context),
                child: const Text('Open paywall'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open paywall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Couldn't start the trial. Check your connection"),
      findsOneWidget,
    );
    expect(find.textContaining('(auth/operation-not-allowed)'), findsOneWidget);
  });

  testWidgets('trial success dismisses only the paywall route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialProvider.overrideWith(_StartedTrialStore.new),
          billingProvider.overrideWith(_UnavailableBillingStore.new),
          accessProvider.overrideWith(_UnlockingAccessStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Paywall host'),
                          TextButton(
                            onPressed: () => showPaywall(context),
                            child: const Text('Open paywall'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('Open host'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open paywall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 7-day free trial'));
    await tester.pumpAndSettle();

    expect(find.text('Paywall host'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
  });
}
