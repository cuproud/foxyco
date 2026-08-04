import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/trial_store.dart';

void main() {
  test('keeps the safe Google API status from sign-in failures', () {
    final tag = trialPlatformFailureTag(
      'google-sign-in',
      PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      ),
    );
    expect(tag, 'google-sign-in/sign_in_failed/api-10');
  });

  test('does not expose arbitrary platform messages', () {
    final tag = trialPlatformFailureTag(
      'google-sign-in',
      PlatformException(
        code: 'sign_in_failed',
        message: 'account-specific free-form detail',
      ),
    );
    expect(tag, 'google-sign-in/sign_in_failed');
    expect(tag, isNot(contains('account-specific')));
  });
}
