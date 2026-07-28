import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/billing_store.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'paywall_sheet.dart';

/// Settings → Unlock. The whole entitlement surface in one accordion: what the
/// driver currently has, how to get more, and how to leave.
///
/// Play requires an in-app account-deletion path once accounts are collected
/// (MONETIZATION_v1.0 §5.1), and this is it — deliberately at the bottom, below
/// a divider, rather than a button anyone hits by accident.
class UnlockSection extends ConsumerWidget {
  const UnlockSection({super.key});

  /// One-line summary for the collapsed accordion header.
  static String summaryOf(Access access) => switch (access.source) {
    AccessSource.unknown => 'Checking…',
    AccessSource.debugBuild => 'Debug build — unlocked',
    AccessSource.purchase || AccessSource.cachedPurchase => 'Unlocked forever',
    AccessSource.trial =>
      access.trialDaysLeft <= 1
          ? 'Trial — last day'
          : 'Trial — ${access.trialDaysLeft} days left',
    AccessSource.none => 'Locked',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final trial = ref.watch(trialProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summaryOf(access), style: text.titleMedium),
        const SizedBox(height: Gap.xs),
        Text(
          switch (access.source) {
            AccessSource.purchase || AccessSource.cachedPurchase =>
              'One-time purchase. No subscription, nothing to renew.',
            AccessSource.trial =>
              'Everything is on. Unlock any time and the trial stops mattering.',
            AccessSource.debugBuild =>
              'Entitlement is forced on in debug builds. Release builds ignore '
                  'this branch entirely.',
            _ =>
              'Live watching still starts, but the pill hides the verdict and '
                  'the numbers until you unlock.',
          },
          style: text.bodySmall,
        ),
        if (trial.hasAccount) ...[
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              // Not const: FoxColors are theme-varying statics.
              Icon(
                Icons.account_circle_outlined,
                size: 16,
                color: FoxColors.textSecondary,
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  trial.email!,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Gap.md),
        if (!access.entitled || access.onTrial)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showPaywall(context),
              style: TextButton.styleFrom(foregroundColor: FoxColors.brandFox),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: Text(
                trial.phase == TrialPhase.preTrial
                    ? 'Start free trial or unlock'
                    : 'Unlock FoxyCo',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Row(
          children: [
            TextButton(
              onPressed: () => _restore(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: FoxColors.textSecondary,
              ),
              child: const Text(
                'Restore purchase',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (trial.hasAccount) ...[
          Divider(color: FoxColors.border, height: Gap.xl),
          Text('Your Google account', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            'Signing you in is what keeps your trial from resetting. Deleting '
            'the account removes it from FoxyCo; a non-identifying record of '
            'when your trial started is kept to prevent trial abuse.',
            style: text.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _confirmDelete(context, ref),
              style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
              child: const Text(
                'Delete my account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await ref.read(accessProvider.notifier).refresh();
    if (!context.mounted) return;
    final found = ref.read(billingProvider) == UnlockStatus.purchased;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            found
                ? 'Purchase restored.'
                : 'No purchase found on this Google account.',
          ),
        ),
      );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        // Say the ugly part out loud: a purchase is owned by the Play account,
        // not by us, so it survives — but the trial does not come back.
        content: const Text(
          'Your Google account is removed from FoxyCo. A purchased unlock is '
          'held by Google Play, so it survives and can be restored. Your free '
          'trial cannot be restarted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final deleted = await ref.read(trialProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    await ref.read(accessProvider.notifier).refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Account deleted.'
                : "Couldn't delete the account. Sign in again and retry.",
          ),
        ),
      );
  }
}
