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
}
