import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/services/billing/billing_store.dart';
import 'package:foxyco/services/billing/entitlement.dart';
import 'package:foxyco/services/billing/trial_store.dart';
import 'package:foxyco/ui/paywall/access_banner.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

class _ActiveTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(
    phase: TrialPhase.active,
    email: 'driver@example.com',
    daysLeft: 7,
  );
}

class _TrialAccessStore extends AccessStore {
  @override
  Access build() => const Access(
    entitled: true,
    source: AccessSource.trial,
    trialDaysLeft: 7,
  );
}

class _LastDayAccessStore extends AccessStore {
  @override
  Access build() => const Access(
    entitled: true,
    source: AccessSource.trial,
    trialDaysLeft: 1,
    trialMinutesLeft: 1422,
  );
}

class _PurchasedBillingStore extends BillingStore {
  @override
  UnlockStatus build() => UnlockStatus.purchased;
}

class _ExpiredTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(phase: TrialPhase.expired);
}

class _StaleLockedAccessStore extends AccessStore {
  @override
  Access build() => const Access(entitled: false, source: AccessSource.none);
}

void main() {
  testWidgets('Home shows the trial countdown from day seven', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialProvider.overrideWith(_ActiveTrialStore.new),
          accessProvider.overrideWith(_TrialAccessStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AccessBanner()),
        ),
      ),
    );

    expect(find.text('7 days left in your free trial'), findsOneWidget);
  });

  testWidgets('Home shows hours and minutes on the last trial day', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trialProvider.overrideWith(_ActiveTrialStore.new),
          accessProvider.overrideWith(_LastDayAccessStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AccessBanner()),
        ),
      ),
    );

    expect(find.text('23h 42m left in your free trial'), findsOneWidget);
  });

  testWidgets('Home hides an expired-trial banner after Play unlocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingProvider.overrideWith(_PurchasedBillingStore.new),
          trialProvider.overrideWith(_ExpiredTrialStore.new),
          accessProvider.overrideWith(_StaleLockedAccessStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AccessBanner()),
        ),
      ),
    );

    expect(find.textContaining('Trial'), findsNothing);
  });
}
