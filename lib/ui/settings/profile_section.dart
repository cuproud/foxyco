import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'garage_section.dart';

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
        Text('GOOGLE ACCOUNT', style: text.labelSmall),
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
                          ? 'Signed in with Google'
                          : 'Not signed in',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trial.email ??
                          'Google sign-in appears when you start the free trial.',
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
        if (trial.hasAccount) ...[
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
                'Log out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out of Google?'),
        content: const Text(
          'You will need to sign into the same Google account again to use any '
          'remaining trial days. A lifetime purchase stays with Google Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
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
          content: Text(signedOut ? 'Logged out.' : "Couldn't log out. Retry."),
        ),
      );
  }
}
