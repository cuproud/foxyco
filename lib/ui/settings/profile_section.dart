import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/billing_store.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'garage_section.dart';
import '../paywall/unlock_section.dart';

/// The driver's local display name plus the Google identity used for a trial.
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = ref.watch(trialProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DriverNameCard(),
        const SizedBox(height: Gap.lg),
        Text('TRIAL ACCOUNT', style: text.labelSmall),
        const SizedBox(height: Gap.sm),
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface2,
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(color: FoxColors.borderSoft),
          ),
          child: Row(
            children: [
              Icon(
                trial.hasAccount
                    ? Icons.account_circle_rounded
                    : Icons.person_off_outlined,
                color: trial.hasAccount
                    ? FoxColors.brandFox
                    : FoxColors.textDisabled,
                size: 24,
              ),
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trial.hasAccount
                          ? 'Trial account signed in'
                          : 'No trial account',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trial.email ?? 'Sign in to restore your trial status.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: FoxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!trial.hasAccount) ...[
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('signin-account'),
              onPressed: () => _signIn(context, ref),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in to trial account'),
            ),
          ),
        ] else ...[
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('logout-account'),
              onPressed: () => _confirmSignOut(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: FoxColors.textSecondary,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Sign out of trial account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Text('UNLOCK', style: text.labelSmall),
        const SizedBox(height: Gap.sm),
        const UnlockSection(),
      ],
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(trialProvider.notifier).signIn();
    if (result == TrialSignInResult.signedIn) {
      await ref.read(accessProvider.notifier).refresh();
    }
    if (!context.mounted) return;
    final trial = ref.read(trialProvider);
    final message = switch (result) {
      TrialSignInResult.cancelled => 'Google sign-in cancelled.',
      TrialSignInResult.failed => "Couldn't sign in. Retry.",
      TrialSignInResult.signedIn
          when ref.read(billingProvider) == UnlockStatus.purchased =>
        'Trial account changed. Lifetime access stays with your Google Play '
            'account.',
      TrialSignInResult.signedIn when trial.phase == TrialPhase.active =>
        'Signed in. Your remaining trial time was restored.',
      TrialSignInResult.signedIn when trial.phase == TrialPhase.expired =>
        'Signed in. This account’s trial has ended.',
      TrialSignInResult.signedIn =>
        'Signed in. You can start your free trial when ready.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of trial account?'),
        content: const Text(
          'You will need to sign into the same Google account again to use any '
          'remaining trial days. Lifetime access is separate and stays with '
          'your Google Play account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final signedOut = await ref.read(trialProvider.notifier).signOut();
    await ref.read(accessProvider.notifier).refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            signedOut
                ? 'Signed out of trial account.'
                : "Couldn't sign out. Retry.",
          ),
        ),
      );
  }
}
