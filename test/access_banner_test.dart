import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
