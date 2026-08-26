import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/billing_store.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'paywall_sheet.dart';

/// Settings → Profile → Access. The entitlement surface in one accordion: what the
/// driver currently has, how to get more, and how to leave.
///
/// Play requires an in-app account-deletion path once accounts are collected;
/// this is deliberately at the bottom, below
/// a divider, rather than a button anyone hits by accident.
class UnlockSection extends ConsumerWidget {
  const UnlockSection({super.key});

  /// One-line summary for the collapsed accordion header.
  static String summaryOf(
    Access access,
    TrialState trial,
  ) => switch (access.source) {
    AccessSource.unknown => 'Checking…',
    AccessSource.debugBuild => 'Debug access enabled',
    AccessSource.purchase || AccessSource.cachedPurchase => 'Lifetime unlocked',
    AccessSource.trial =>
      access.trialDaysLeft <= 1
          ? 'Trial active · 1 day remaining'
          : 'Trial active · ${access.trialDaysLeft} days remaining',
    AccessSource.none when trial.phase == TrialPhase.expired => 'Trial ended',
    AccessSource.none => 'Trial not started',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final trial = ref.watch(trialProvider);
    final text = Theme.of(context).textTheme;
    final lifetime =
        access.source == AccessSource.purchase ||
        access.source == AccessSource.cachedPurchase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lifetime)
          Text(
            'Use Restore purchase after reinstalling FoxyCo or changing devices.',
            style: text.bodyMedium?.copyWith(color: FoxColors.textPrimary),
          ),
        if (!lifetime) ...[
          Text(summaryOf(access, trial), style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(switch (access.source) {
            AccessSource.purchase || AccessSource.cachedPurchase =>
              'Lifetime access is managed by your Google Play account.',
            AccessSource.trial =>
              'Everything is on. Unlock any time to keep access after the trial.',
            AccessSource.debugBuild =>
              'Entitlement is forced on in debug builds. Release builds ignore '
                  'this branch entirely.',
            _ =>
              'Live watching still starts, but the pill hides the verdict and '
                  'the numbers until you unlock.',
          }, style: text.bodySmall),
        ],
        if (trial.hasAccount && !lifetime) ...[
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
                  'Google account · ${trial.email!}',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: lifetime ? Gap.sm : Gap.md),
        if (!access.entitled || access.onTrial)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showPaywall(context),
              style: TextButton.styleFrom(foregroundColor: FoxColors.brandText),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: Text(
                trial.phase == TrialPhase.preTrial
                    ? 'Start free trial or unlock'
                    : 'Unlock FoxyCo',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _restore(context, ref),
          style: OutlinedButton.styleFrom(foregroundColor: FoxColors.brandText),
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: const Text(
            'Restore purchase',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (trial.hasAccount) ...[
          Divider(color: FoxColors.border, height: Gap.xl),
          Text('Account & privacy', style: text.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            lifetime
                ? 'Delete your FoxyCo account and email. Your Google Play '
                      'lifetime purchase remains available to restore.'
                : 'Signing in protects your trial from resetting. Deleting '
                      'the account removes it from FoxyCo; a non-identifying '
                      'trial-start record is kept to prevent trial abuse.',
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
    final status = ref.read(billingProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            UnlockStatus.purchased => 'Purchase restored.',
            UnlockStatus.unavailable =>
              "Couldn't check Google Play. Check your connection and retry.",
            _ => 'No lifetime purchase found in Google Play.',
          }),
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
          'Your Firebase account and email are deleted. FoxyCo keeps only a '
          'random ID and trial-start date to prevent repeated free trials; it '
          'has no email attached after deletion. Lifetime access '
          'is held by Google Play, so it survives and can be restored.',
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
