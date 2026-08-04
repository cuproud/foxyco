import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxyco/services/billing/trial_store.dart';
import 'package:foxyco/ui/settings/profile_section.dart';
import 'package:foxyco/ui/theme/app_theme.dart';

class _SignedInTrialStore extends TrialStore {
  @override
  TrialState build() => const TrialState(
    phase: TrialPhase.active,
    email: 'driver@example.com',
    daysLeft: 4,
  );
}

class _SignedOutTrialStore extends TrialStore {
  bool signInCalled = false;

  @override
  TrialState build() => const TrialState(phase: TrialPhase.preTrial);

  @override
  Future<TrialSignInResult> signIn() async {
    signInCalled = true;
    state = const TrialState(
      phase: TrialPhase.active,
      email: 'returning@example.com',
      daysLeft: 2,
    );
    return TrialSignInResult.signedIn;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profile shows Google email, saved-name control and logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trialProvider.overrideWith(_SignedInTrialStore.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: ProfileSection()),
          ),
        ),
      ),
    );

    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
    expect(find.text('driver@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('logout-account')), findsOneWidget);
  });

  testWidgets('signed-out profile can select Google account', (tester) async {
    final container = ProviderContainer(
      overrides: [trialProvider.overrideWith(_SignedOutTrialStore.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(child: ProfileSection()),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('signin-account')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('signin-account')));
    await tester.pumpAndSettle();

    expect(
      (container.read(trialProvider.notifier) as _SignedOutTrialStore)
          .signInCalled,
      isTrue,
    );
    expect(find.text('returning@example.com'), findsOneWidget);
  });
}
