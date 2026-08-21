import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/billing_store.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'garage_section.dart';
import '../paywall/unlock_section.dart';

/// The driver's local display name plus the Google identity used for access.
class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = ref.watch(trialProvider);
    final access = ref.watch(accessProvider);
    final text = Theme.of(context).textTheme;

    final accessTitle = switch (access.source) {
      AccessSource.purchase ||
      AccessSource.cachedPurchase => 'Lifetime plan · Active',
      AccessSource.trial =>
        'Trial active · ${access.trialDaysLeft} '
            '${access.trialDaysLeft == 1 ? 'day' : 'days'} remaining',
      AccessSource.debugBuild => 'Debug access enabled',
      AccessSource.unknown => 'Checking access…',
      AccessSource.none when trial.phase == TrialPhase.preTrial =>
        'Trial not started',
      AccessSource.none when trial.phase == TrialPhase.expired => 'Trial ended',
      AccessSource.none => 'No access',
    };
    final accessSubtitle = switch (access.source) {
      AccessSource.purchase || AccessSource.cachedPurchase =>
        trial.email ?? 'Managed by your Google Play account.',
      AccessSource.trial when trial.email != null => trial.email!,
      AccessSource.trial => 'Sign in with Google to protect your trial.',
      AccessSource.none when trial.hasAccount => trial.email!,
      AccessSource.none => 'Sign in with Google to protect your trial.',
      _ => trial.email ?? 'Your access status is being checked.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DriverNameCard(),
        const SizedBox(height: Gap.lg),
        Text('ACCOUNT & ACCESS', style: text.labelSmall),
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
                access.entitled
                    ? Icons.account_circle_rounded
                    : Icons.person_off_outlined,
                color: access.entitled
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
                      accessTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accessSubtitle,
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
              label: const Text('Sign in with Google to protect your trial'),
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
                'Sign out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Text('ACCESS', style: text.labelSmall),
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
        'Google account changed. Lifetime access stays with your Google Play '
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
        title: const Text('Sign out?'),
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
                ? 'Signed out of Google account.'
                : "Couldn't sign out. Retry.",
          ),
        ),
      );
  }
}
