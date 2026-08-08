import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing_store.dart';
import 'fox_clock.dart';
import 'purchase_verifier.dart';
import 'trial_store.dart';

/// Forces entitlement on in debug builds so the pill can be worked on without a
/// Play purchase or a live trial (MONETIZATION_v1.0 §6.2).
///
/// Gated on [kDebugMode], which is a compile-time constant, so the whole branch
/// is tree-shaken out of release builds. It must never become a runtime setting,
/// a flavor string or a hidden preference.
const kDebugUnlocked = kDebugMode;

/// Drop-dead date for closed-track builds (§6 layer 3): past it, the paywall
/// applies no matter what the trial says, so a tester build can't become a
/// permanent free copy. Empty (the default) means no expiry — that is what
/// production ships with.
///
/// `flutter build apk --dart-define=BUILD_EXPIRY=2026-09-30`
const _buildExpiryRaw = String.fromEnvironment('BUILD_EXPIRY');

/// Why the driver has (or hasn't) got access. Drives the copy: "3 days left" is
/// a very different banner from "trial ended".
enum AccessSource {
  /// Still resolving Play and Firestore. Never lock the UI on this.
  unknown,

  /// Debug build override.
  debugBuild,

  /// Signature-verified Play purchase, or a redeemed promo code — Play reports
  /// both identically, which is what §6.1 wants.
  purchase,

  /// A previously verified purchase, honoured while Play is unreachable.
  cachedPurchase,

  /// Inside the 7-day trial.
  trial,

  /// Nothing grants access: pre-trial, expired, or the grace window lapsed.
  none,
}

/// The one answer the rest of the app asks for: is this driver entitled?
@immutable
class Access {
  final bool entitled;
  final AccessSource source;

  /// Days left in the trial, 0 when not on one. Banner copy only.
  final int trialDaysLeft;

  /// Minutes left in the trial, rounded up. Drives the final-day countdown.
  final int trialMinutesLeft;

  /// The cached verdict has gone [offlineGrace] - 2 days without a successful
  /// check, so the driver gets a warning before it lapses mid-shift (§3.5).
  final bool cacheGoingStale;

  /// Days before the unverified cache lapses, for that warning's copy. Only
  /// meaningful while [cacheGoingStale].
  final int graceDaysLeft;

  /// Release build with no `PLAY_PUBLIC_KEY` compiled in: every receipt fails
  /// verification, so nobody can buy anything (§3.9 — fails closed, loudly).
  final bool licenceKeyMissing;

  const Access({
    required this.entitled,
    required this.source,
    this.trialDaysLeft = 0,
    this.trialMinutesLeft = 0,
    this.cacheGoingStale = false,
    this.graceDaysLeft = 0,
    this.licenceKeyMissing = false,
  });

  static const resolving = Access(
    entitled: false,
    source: AccessSource.unknown,
  );

  /// The whole entitlement decision, as a pure function of what Play said, what
  /// the trial says, and the clock (MONETIZATION_v1.0 §11).
  ///
  /// Pulled out of [AccessStore] so the money path is testable without Play,
  /// Firebase or prefs — and so the precedence is readable in one place.
  /// [debugUnlocked] and [buildExpiry] are parameters rather than the constants
  /// they normally come from, for the same reason.
  factory Access.derive({
    required UnlockStatus unlock,
    required TrialState trial,
    required DateTime now,
    required DateTime? purchasedAt,
    bool debugUnlocked = kDebugUnlocked,
    DateTime? buildExpiry,
    bool licenceKeyMissing = false,
  }) {
    final purchaseAge = purchasedAt == null
        ? null
        : now.difference(purchasedAt);
    final cachedPurchase =
        purchaseAge != null &&
        !purchaseAge.isNegative &&
        purchaseAge < offlineGrace;

    // Age of the trial check, for the day-5 warning. Only worth warning about
    // while the driver actually has something to lose.
    final trialStale = trial.staleness(now);

    // §3.5 applies to the trial exactly as it does to a cached purchase: the
    // cached verdict is honoured for [offlineGrace] without a successful server
    // check, then it lapses. Without this an active trial was granted purely on
    // arithmetic against the local clock — so airplane mode plus a rolled-back
    // clock plus cleared app data kept the 7 days running forever, which is the
    // piracy ceiling §3.5 says it is closing.
    //
    // A null staleness means we have NEVER reached the server. Kept permissive:
    // that is a first launch in a dead zone, not a cracker, and locking it would
    // punish the one driver who cannot do anything about it.
    final trialLeft = trial.startedAt == null
        ? Duration.zero
        : trialDuration - now.difference(trial.startedAt!);
    final trialActiveNow = trial.isActive && trialLeft > Duration.zero;
    final trialUsable =
        trialActiveNow && (trialStale == null || trialStale < offlineGrace);

    final (bool entitled, AccessSource source) = switch (null) {
      // Debug first: a dev build must work with neither Play nor Firebase.
      _ when debugUnlocked => (true, AccessSource.debugBuild),
      // The kill date beats anything a tester build could otherwise claim.
      _ when buildExpiry != null && !now.isBefore(buildExpiry) => (
        false,
        AccessSource.none,
      ),
      _ when unlock == UnlockStatus.purchased => (true, AccessSource.purchase),
      _ when cachedPurchase => (true, AccessSource.cachedPurchase),
      _ when trialUsable => (true, AccessSource.trial),
      // Still asking both sides: stay unresolved rather than flashing a paywall
      // at a driver who is only mid-boot.
      _
          when unlock == UnlockStatus.unknown ||
              trial.phase == TrialPhase.unknown =>
        (false, AccessSource.unknown),
      _ => (false, AccessSource.none),
    };
    final warningAge = switch (source) {
      AccessSource.trial => trialStale,
      AccessSource.cachedPurchase => purchaseAge,
      _ => null,
    };
    final goingStale =
        warningAge != null &&
        warningAge > offlineGrace - const Duration(days: 2);
    final graceLeft = warningAge == null
        ? 0
        : (offlineGrace - warningAge).inHours ~/ 24;

    return Access(
      entitled: entitled,
      source: source,
      trialDaysLeft: trialActiveNow
          ? (trialLeft.inSeconds / Duration.secondsPerDay).ceil()
          : 0,
      trialMinutesLeft: trialActiveNow
          ? (trialLeft.inSeconds / Duration.secondsPerMinute).ceil()
          : 0,
      cacheGoingStale: goingStale,
      graceDaysLeft: graceLeft < 0 ? 0 : graceLeft,
      licenceKeyMissing: licenceKeyMissing,
    );
  }

  /// True once we know enough to show a paywall. Guards against flashing "trial
  /// ended" over a driver who is simply mid-boot.
  bool get resolved => source != AccessSource.unknown;

  bool get onTrial => source == AccessSource.trial;
}

/// Combines the two independent sources of truth — Play for the purchase,
/// Firestore for the trial — into a single `entitled` bool
/// (MONETIZATION_v1.0 §11).
///
/// `entitled = purchased OR trial active`, cached with an offline grace window.
/// Everything fails CLOSED: while Play is unreachable and the trial unknown, a
/// driver with no cached purchase is locked, not waved through.
class AccessStore extends Notifier<Access> {
  /// When a signature-verified purchase was last seen, local clock. This is the
  /// offline grace window's anchor — Play is unreachable in a dead zone and a
  /// paid-up driver must not get locked mid-shift.
  static const _keyPurchasedAt = 'foxyco.unlock.verifiedAt.v1';

  DateTime? _purchasedAt;
  int _purchaseRevision = 0;
  // Defaults true for focused test subclasses that override [build]. The real
  // provider flips it false while its purchase cache is loading.
  bool _cacheLoaded = true;
  Future<void>? _deriveInFlight;
  bool _deriveAgain = false;
  Timer? _timeBoundaryTimer;

  @protected
  Future<DateTime> currentTime() => FoxClock.now();

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @protected
  bool get debugUnlocked => kDebugUnlocked;

  @protected
  Timer createTimer(Duration delay, void Function() callback) =>
      Timer(delay, callback);

  @override
  Access build() {
    _cacheLoaded = false;
    // Both halves feed the same verdict; either changing re-derives it.
    ref.listen(billingProvider, (_, _) => _derive());
    ref.listen(trialProvider, (_, _) => _derive());
    ref.onDispose(() => _timeBoundaryTimer?.cancel());
    _loadCache().whenComplete(() {
      _cacheLoaded = true;
      if (ref.mounted) unawaited(_derive());
    });
    return Access.resolving;
  }

  Future<void> _loadCache() async {
    final revision = _purchaseRevision;
    try {
      final prefs = await preferences();
      final ms = prefs.getInt(_keyPurchasedAt);
      if (ms != null && revision == _purchaseRevision) {
        _purchasedAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo unlock cache read skipped: $e');
    }
  }

  Future<void> _setPurchasedAt(DateTime? at) async {
    _purchaseRevision++;
    _purchasedAt = at;
    try {
      final prefs = await preferences();
      if (at == null) {
        await prefs.remove(_keyPurchasedAt);
      } else {
        await prefs.setInt(_keyPurchasedAt, at.millisecondsSinceEpoch);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo unlock cache write skipped: $e');
    }
  }

  /// Recompute from whatever both stores currently say. Concurrent requests
  /// coalesce into one final pass so an older async clock/cache operation can
  /// never overwrite newer Play or trial evidence.
  Future<void> _derive() {
    _deriveAgain = true;
    return _deriveInFlight ??= _runDerivations().whenComplete(() {
      _deriveInFlight = null;
    });
  }

  Future<void> _runDerivations() async {
    while (_deriveAgain) {
      _deriveAgain = false;
      final now = await currentTime();
      if (!ref.mounted) return;
      final unlock = ref.read(billingProvider);
      final trial = ref.read(trialProvider);

      // A slow SharedPreferences read must not publish a false lock and flash
      // “Trial ended” before a valid cached purchase is known.
      if (!_cacheLoaded) continue;

      if (unlock == UnlockStatus.purchased) {
        // Refresh the grace anchor every time Play confirms it.
        if (_purchasedAt == null ||
            now.difference(_purchasedAt!).inHours > 12) {
          await _setPurchasedAt(now);
          if (!ref.mounted) return;
        }
      } else if (unlock == UnlockStatus.notPurchased) {
        // Play answered and owns no purchase for this account — a refund, or a
        // receipt that stopped verifying. Drop the cache; keeping it would
        // extend access past a refund by the whole grace window.
        if (_purchasedAt != null) {
          await _setPurchasedAt(null);
          if (!ref.mounted) return;
        }
      }

      if (_deriveAgain) continue;
      final next = Access.derive(
        unlock: unlock,
        trial: trial,
        now: now,
        purchasedAt: _purchasedAt,
        debugUnlocked: debugUnlocked,
        buildExpiry: _buildExpiry,
        // A release build with no licensing key compiled in can verify nothing,
        // so nobody can buy anything (§3.9 — fails closed, and says so).
        licenceKeyMissing:
            !kDebugMode && PurchaseVerifier.publicKeyBase64.isEmpty,
      );
      state = next;
      _scheduleTimeCheck(access: next, trial: trial, now: now);
    }
  }

  void _scheduleTimeCheck({
    required Access access,
    required TrialState trial,
    required DateTime now,
  }) {
    _timeBoundaryTimer?.cancel();
    _timeBoundaryTimer = null;
    DateTime? boundary;
    void consider(DateTime? candidate) {
      if (candidate == null || !candidate.isAfter(now)) return;
      if (boundary == null || candidate.isBefore(boundary!)) {
        boundary = candidate;
      }
    }

    if (!debugUnlocked) consider(_buildExpiry);
    switch (access.source) {
      case AccessSource.trial:
        consider(now.add(const Duration(minutes: 1)));
        consider(trial.startedAt?.add(trialDuration));
        consider(trial.verifiedAt?.add(offlineGrace));
      case AccessSource.cachedPurchase:
        consider(_purchasedAt?.add(offlineGrace));
      case AccessSource.unknown:
      case AccessSource.debugBuild:
      case AccessSource.purchase:
      case AccessSource.none:
        break;
    }
    final next = boundary;
    if (next == null) return;
    _timeBoundaryTimer = createTimer(next.difference(now), () {
      unawaited(_derive());
    });
  }

  /// Kill date for closed-track builds (§6 layer 3), or null in production.
  static DateTime? get _buildExpiry => _buildExpiryRaw.isEmpty
      ? null
      : DateTime.tryParse(_buildExpiryRaw)?.toUtc();

  /// Re-ask both sides. Called on app resume and after a purchase or trial
  /// start, so the pill unlocks without a restart.
  ///
  /// [sampled] passes the anti-piracy sampling down to the trial read — resume
  /// fires often, and a Firestore round trip every time would be both wasteful
  /// and pointless (the trial's end date is already known locally). Play is
  /// re-asked every time regardless: the owned-products query is a local Play
  /// Store call and doubles as the acknowledgment recovery path for a purchase
  /// interrupted mid-flow (§3.8).
  Future<void> refresh({bool sampled = false}) async {
    await ref.read(trialProvider.notifier).refresh(sampled: sampled);
    await ref.read(billingProvider.notifier).restore();
    await _derive();
  }

  /// Re-evaluate time-based access without contacting Play or Firestore.
  Future<void> tick() => _derive();
}

final accessProvider = NotifierProvider<AccessStore, Access>(AccessStore.new);

/// Just the bool, for the many widgets that need nothing else. Separate provider
/// so they don't rebuild when only `trialDaysLeft` moves.
final entitledProvider = Provider<bool>(
  (ref) => ref.watch(accessProvider).entitled,
);
