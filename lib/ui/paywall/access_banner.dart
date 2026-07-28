import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';
import 'paywall_sheet.dart';

/// The trial/unlock strip at the top of Home (MONETIZATION_v1.0 §4, §3.5).
///
/// Says nothing at all in the common case — a driver inside their trial with
/// days to spare, or one who has paid, sees no banner. It speaks up only when
/// there is something to do:
///
///   • locked (pre-trial or expired) → the ask
///   • last 3 days of the trial → a countdown
///   • cached verdict about to lapse → "we need to check with Google Play"
///
/// Zero height when silent, so Home's layout doesn't need to know.
class AccessBanner extends ConsumerWidget {
  const AccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final trial = ref.watch(trialProvider);

    // Mid-boot: say nothing rather than flash "trial ended" at a paying driver.
    if (!access.resolved) return const SizedBox.shrink();

    final (String text, IconData icon, Color tint)? message = switch (access) {
      // Offline too long. Comes FIRST: a driver about to be locked mid-shift
      // needs this more than a trial countdown.
      Access(cacheGoingStale: true, entitled: true) => (
        access.graceDaysLeft <= 0
            ? "Couldn't reach Google Play — unlock check needed now"
            : "Couldn't reach Google Play — unlock check needed in "
                  '${access.graceDaysLeft} '
                  '${access.graceDaysLeft == 1 ? 'day' : 'days'}',
        Icons.cloud_off_rounded,
        VerdictColors.ok,
      ),
      Access(entitled: false) when trial.phase == TrialPhase.preTrial => (
        'Start your 7-day free trial',
        Icons.local_activity_outlined,
        FoxColors.brandFox,
      ),
      Access(entitled: false) => (
        'Trial ended — unlock FoxyCo',
        Icons.lock_outline_rounded,
        FoxColors.brandFox,
      ),
      // Countdown only in the last stretch; a daily nag from day one would just
      // train the driver to ignore this strip.
      Access(source: AccessSource.trial) when access.trialDaysLeft <= 3 => (
        access.trialDaysLeft <= 1
            ? 'Last day of your free trial'
            : '${access.trialDaysLeft} days left in your free trial',
        Icons.timer_outlined,
        VerdictColors.ok,
      ),
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();

    final (text, icon, tint) = message;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.cardSm),
        onTap: () => showPaywall(context),
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: Gap.sm + Gap.xs),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: FoxColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: FoxColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
