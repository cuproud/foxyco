import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/billing/billing_store.dart';
import '../../services/billing/entitlement.dart';
import '../../services/billing/trial_store.dart';
import '../theme/tokens.dart';

/// Where the driver goes to redeem a Play promo code (§6.1). Play has no
/// in-app redemption API for one-time products; this is the supported path.
const _redeemUrl = 'https://play.google.com/redeem';

/// One-shot request to open the paywall, in the shape of [pendingOfferProvider]:
/// set it from anywhere, [RootShell] shows the sheet and clears it.
///
/// Needed because the locked pill lives in the overlay isolate — it can't push a
/// route, so it sends an action and the main isolate raises this flag.
final paywallRequestProvider = NotifierProvider<PaywallRequest, bool>(
  PaywallRequest.new,
);

class PaywallRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

/// The unlock sheet: trial start, one-time purchase, restore, redeem.
///
/// Opened from the Home banner, Settings → Profile → Access, and a tap on the
/// locked pill.
Future<void> showPaywall(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
  ),
  builder: (_) => const _PaywallSheet(),
);

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet();

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  /// A sign-in or purchase flow is in flight — disables the buttons so a second
  /// tap can't open a second Google sheet.
  bool _working = false;

  /// Entitlement can flip while the explicit trial/purchase action is still
  /// awaiting its refresh. Both paths want to dismiss this route, so guard the
  /// pop: a second pop would remove the app screen underneath the sheet and
  /// leave the driver looking at a blank navigator.
  bool _closing = false;

  /// Last failure, shown inline. A SnackBar can't be used while the sheet is
  /// open: ScaffoldMessenger draws it in the Scaffold *below* this route, so the
  /// sheet covers it and the driver sees a dead button.
  String? _notice;

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    if (!mounted || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _startTrial() => _run(() async {
    final notifier = ref.read(trialProvider.notifier);
    final result = await notifier.startTrial();
    if (!mounted) return;
    switch (result) {
      case TrialStartResult.started:
        await ref.read(accessProvider.notifier).refresh();
        _close();
      case TrialStartResult.alreadyExpired:
        // The whole point of the server-side start date: a reinstall lands here
        // instead of getting a fresh week (§3.4.1).
        setState(
          () => _notice = 'This Google account already used its free trial.',
        );
      case TrialStartResult.cancelled:
        final why = notifier.lastStartError;
        setState(
          () => _notice =
              'Google sign-in was cancelled. Try again and select the Google '
              'account that owns your trial.'
              "${why == null ? '' : '\n($why)'}",
        );
      case TrialStartResult.failed:
        final why = notifier.lastStartError;
        setState(
          () => _notice =
              "Couldn't start the trial. Check your connection and retry."
              "${why == null ? '' : '\n($why)'}",
        );
    }
  });

  Future<void> _buy() => _run(() async {
    await ref.read(billingProvider.notifier).buy();
    // No success message here: Play's own sheet is the confirmation, and the
    // purchase lands asynchronously on the stream. The listener below closes
    // this sheet when entitlement actually flips.
  });

  Future<void> _restore() => _run(() async {
    await ref.read(accessProvider.notifier).refresh();
    if (!mounted) return;
    switch (ref.read(billingProvider)) {
      case UnlockStatus.purchased:
        break;
      case UnlockStatus.unavailable:
        _say("Couldn't check Google Play. Check your connection and retry.");
      default:
        _say('No lifetime purchase found in Google Play.');
    }
  });

  Future<void> _redeem() => _run(() async {
    final opened = await launchUrl(
      Uri.parse(_redeemUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _say("Couldn't open Google Play.");
  });

  @override
  Widget build(BuildContext context) {
    final unlock = ref.watch(billingProvider);
    final trial = ref.watch(trialProvider);
    final access = ref.watch(accessProvider);

    // Purchase landed while the sheet was open (Play's flow is asynchronous) —
    // listen to Play itself because an active trial is already entitled.
    ref.listen(billingProvider, (_, unlock) {
      if (unlock == UnlockStatus.purchased) _close();
    });

    // Play supplies the storefront-localized price. Never guess a currency
    // while product details are loading.
    final price = ref.watch(billingPriceProvider);
    final canTrial = trial.phase == TrialPhase.preTrial;
    final unlockLabel = price == null
        ? (canTrial
              ? 'Unlock now with Google Play'
              : 'Unlock forever with Google Play')
        : (canTrial ? 'Unlock now — $price' : 'Unlock forever — $price');

    return Container(
      margin: const EdgeInsets.all(Gap.sm),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Not const: the palette tokens are plain statics that change with the
        // theme, so a const gradient would bake in whichever theme built first.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FoxColors.inkSoft, FoxColors.ink],
        ),
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: FoxColors.border),
        boxShadow: Shadows.hero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FoxColors.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.lg + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              canTrial
                                  ? 'Try FoxyCo on your next shift'
                                  : 'Unlock every verdict for life',
                              style: TextStyle(
                                fontFamily: FoxFonts.display,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: FoxColors.textPrimary,
                              ),
                            ),
                            Text(
                              canTrial
                                  ? 'Use every feature free for 7 days, then choose whether to buy lifetime access.'
                                  : 'One Google Play purchase. No subscription.',
                              style: TextStyle(
                                fontFamily: FoxFonts.sans,
                                fontSize: 13,
                                color: FoxColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.cardSm),
                        child: Image.asset(
                          'assets/tips/fox_tip_earnings.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          semanticLabel: 'Fox holding shift earnings',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  // Anchor the price to the driver's own arithmetic, not to a
                  // competitor's (§6.3 — a hardcoded rival price rots).
                  const _Bullet('See weak offers before you decide'),
                  const _Bullet(
                    'Compare offers using your own distance or hourly rules',
                  ),
                  const _Bullet('Pay once for lifetime access'),
                  const SizedBox(height: Gap.md),
                  if (access.licenceKeyMissing)
                    const _Notice(
                      'Purchases are unavailable in this build. Please update '
                      'FoxyCo from Google Play.',
                    ),
                  if (unlock == UnlockStatus.pending)
                    // Slow payment method (cash, carrier billing). Not
                    // entitlement until Play says purchased (§3.8).
                    const _Notice(
                      'Payment processing. This can take a while with cash or '
                      'carrier billing — FoxyCo unlocks itself the moment it '
                      'clears.',
                    ),
                  if (unlock == UnlockStatus.unavailable)
                    const _Notice(
                      "Google Play isn't reachable right now, so buying is off. "
                      'Your trial still works.',
                    ),
                  if (_notice != null) _Notice(_notice!),
                  if (canTrial)
                    _PrimaryButton(
                      label: 'Start 7-day free trial',
                      // Sign-in is what makes the trial unresettable; say so
                      // rather than springing a Google sheet on the driver.
                      note:
                          'Signs you in with Google so your trial follows you '
                          'to a new phone.',
                      busy: _working,
                      onTap: _startTrial,
                    ),
                  if (canTrial) const SizedBox(height: Gap.sm),
                  _PrimaryButton(
                    label: unlockLabel,
                    note: 'One-time purchase through Google Play.',
                    outlined: canTrial,
                    busy: _working,
                    onTap: unlock == UnlockStatus.unavailable || price == null
                        ? null
                        : _buy,
                  ),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _TextAction(
                          label: 'Restore purchase',
                          onTap: _working ? null : _restore,
                        ),
                      ),
                      Expanded(
                        child: _TextAction(
                          label: 'Redeem code',
                          onTap: _working ? null : _redeem,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, size: 17, color: FoxColors.brandFox),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: FoxFonts.sans,
              fontSize: 13.5,
              height: 1.35,
              color: FoxColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Non-blocking explanation — Play unreachable, payment pending, build
/// misconfigured. Deliberately not an error dialog: none of these are the
/// driver's fault and none of them stop the app working.
class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Gap.sm),
    padding: const EdgeInsets.all(Gap.sm),
    decoration: BoxDecoration(
      color: FoxColors.bgSurface,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: FoxColors.border),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: FoxFonts.sans,
        fontSize: 12.5,
        height: 1.35,
        color: FoxColors.textSecondary,
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
    this.note,
    this.outlined = false,
  });

  final String label;
  final String? note;
  final bool busy;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: outlined ? Colors.transparent : FoxColors.brandFox,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: outlined ? FoxColors.brandFox : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: outlined ? null : Shadows.glowSoft,
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontFamily: FoxFonts.sans,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          // Ink on orange, cream on the outlined variant — same
                          // pairing the bottom nav uses.
                          color: outlined
                              ? FoxColors.brandFox
                              : const Color(0xFF0E1F17),
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(
              note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: FoxFonts.sans,
                fontSize: 11.5,
                color: FoxColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: FoxFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? FoxColors.textDisabled
                : FoxColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: FoxColors.textDisabled,
          ),
        ),
      ),
    ),
  );
}
