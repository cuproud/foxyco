import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/services/billing/billing_store.dart';
import 'package:foxyco/services/billing/entitlement.dart';
import 'package:foxyco/services/billing/trial_store.dart';

/// The money path: who gets to see a verdict, and who gets asked to pay
/// (docs/MONETIZATION_v1.0 §3.1–§3.5, §10 acceptance criteria).
///
/// Both decisions were pulled out as pure functions precisely so this file needs
/// no Play, no Firebase and no prefs. `debugUnlocked: false` everywhere — these
/// tests run in debug, where the real constant is true and would mask every
/// other rule.
void main() {
  final now = DateTime.utc(2026, 7, 28, 12);

  TrialState trialStartedAgo(Duration ago, {Duration? verifiedAgo}) =>
      TrialState.from(
        startedAt: now.subtract(ago),
        verifiedAt: verifiedAgo == null ? null : now.subtract(verifiedAgo),
        email: 'driver@example.com',
        now: now,
      );
  final preTrial = TrialState.from(
    startedAt: null,
    verifiedAt: null,
    email: null,
    now: now,
  );

  Access derive({
    UnlockStatus unlock = UnlockStatus.notPurchased,
    TrialState? trial,
    DateTime? purchasedAt,
    DateTime? buildExpiry,
  }) => Access.derive(
    unlock: unlock,
    trial: trial ?? preTrial,
    now: now,
    purchasedAt: purchasedAt,
    debugUnlocked: false,
    buildExpiry: buildExpiry,
  );

  group('trial timeline', () {
    test('no start date is PRE_TRIAL, which is locked', () {
      final t = TrialState.from(
        startedAt: null,
        verifiedAt: null,
        email: null,
        now: now,
      );
      expect(t.phase, TrialPhase.preTrial);
      expect(t.isActive, isFalse);
      expect(derive(trial: t).entitled, isFalse);
    });

    test('inside 7 days is active, with days left rounded up', () {
      // 2 days in: 5 whole days and change remain, and the driver should read
      // "5 days left" rather than 4.
      final t = trialStartedAgo(const Duration(days: 2, hours: 3));
      expect(t.phase, TrialPhase.active);
      expect(t.daysLeft, 5);
    });

    test('the last few hours still read as one day, not zero', () {
      final t = trialStartedAgo(const Duration(days: 6, hours: 20));
      expect(t.phase, TrialPhase.active);
      expect(t.daysLeft, 1);
      final access = derive(trial: t);
      expect(access.trialDaysLeft, 1);
      expect(access.trialMinutesLeft, 240);
    });

    test('past 7 days is expired and locked', () {
      final t = trialStartedAgo(const Duration(days: 7, minutes: 1));
      expect(t.phase, TrialPhase.expired);
      expect(t.daysLeft, 0);
      final access = derive(trial: t);
      expect(access.entitled, isFalse);
      expect(access.trialMinutesLeft, 0);
    });
  });

  group('entitlement precedence', () {
    test('a verified Play purchase entitles', () {
      final a = derive(unlock: UnlockStatus.purchased);
      expect(a.entitled, isTrue);
      expect(a.source, AccessSource.purchase);
    });

    test('an active trial entitles', () {
      final a = derive(trial: trialStartedAgo(const Duration(days: 1)));
      expect(a.entitled, isTrue);
      expect(a.source, AccessSource.trial);
    });

    test('a purchase outranks the trial as the reported source', () {
      final a = derive(
        unlock: UnlockStatus.purchased,
        trial: trialStartedAgo(const Duration(days: 1)),
      );
      expect(a.source, AccessSource.purchase);
    });

    test('pending payment grants nothing (§3.8)', () {
      // Cash and carrier billing sit in `pending` for hours. Play has not taken
      // the money, so there is nothing to unlock yet.
      final a = derive(unlock: UnlockStatus.pending);
      expect(a.entitled, isFalse);
    });

    test('mid-boot stays unresolved rather than flashing a paywall', () {
      final a = derive(unlock: UnlockStatus.unknown, trial: TrialState.initial);
      expect(a.source, AccessSource.unknown);
      expect(a.resolved, isFalse);
      expect(a.entitled, isFalse);
    });

    test('resolved expired trial still waits for Play ownership', () {
      final a = derive(
        unlock: UnlockStatus.unknown,
        trial: trialStartedAgo(const Duration(days: 8)),
      );
      expect(a.resolved, isFalse);
      expect(a.source, AccessSource.unknown);
    });

    test('resolved empty Play ownership still waits for trial state', () {
      final a = derive(
        unlock: UnlockStatus.notPurchased,
        trial: TrialState.initial,
      );
      expect(a.resolved, isFalse);
      expect(a.source, AccessSource.unknown);
    });

    test('Play unreachable with no trial and no cache is LOCKED, not open', () {
      // The fail-closed case that matters: no network, nothing cached, and a
      // trial that was never started must not be waved through.
      final a = derive(unlock: UnlockStatus.unavailable);
      expect(a.entitled, isFalse);
      expect(a.resolved, isTrue);
    });
  });

  group('Play ownership refresh', () {
    test('successful empty query clears a refunded local unlock', () {
      expect(
        ownedPurchaseQueryStatus(
          current: UnlockStatus.purchased,
          succeeded: true,
          ownsGenuinePurchase: false,
        ),
        UnlockStatus.notPurchased,
      );
    });

    test('query failure keeps a verified purchase for offline grace', () {
      expect(
        ownedPurchaseQueryStatus(
          current: UnlockStatus.purchased,
          succeeded: false,
          ownsGenuinePurchase: false,
        ),
        UnlockStatus.purchased,
      );
    });

    test('valid one-time purchase wins over a partial query error', () {
      expect(
        ownedPurchaseQueryStatus(
          current: UnlockStatus.unknown,
          succeeded: false,
          ownsGenuinePurchase: true,
        ),
        UnlockStatus.purchased,
      );
    });

    test(
      'stale empty query cannot overwrite newer purchase-stream evidence',
      () {
        expect(
          ownedPurchaseQueryStatus(
            current: UnlockStatus.purchased,
            succeeded: true,
            ownsGenuinePurchase: false,
            queryIsCurrent: false,
          ),
          UnlockStatus.purchased,
        );
      },
    );
  });

  group('offline grace window (§3.5)', () {
    test('a cached purchase survives Play being unreachable for a week', () {
      final a = derive(
        unlock: UnlockStatus.unavailable,
        purchasedAt: now.subtract(const Duration(days: 6, hours: 23)),
      );
      expect(a.entitled, isTrue);
      expect(a.source, AccessSource.cachedPurchase);
    });

    test('and lapses once past the grace window', () {
      final a = derive(
        unlock: UnlockStatus.unavailable,
        purchasedAt: now.subtract(const Duration(days: 7, minutes: 1)),
      );
      expect(a.entitled, isFalse);
      expect(a.source, AccessSource.none);
    });

    test('warns before a cached purchase verification lapses', () {
      final a = derive(
        unlock: UnlockStatus.unavailable,
        purchasedAt: now.subtract(const Duration(days: 5, hours: 1)),
      );
      expect(a.source, AccessSource.cachedPurchase);
      expect(a.cacheGoingStale, isTrue);
      expect(a.graceDaysLeft, 1);
    });

    test('rejects a future-dated purchase cache', () {
      final a = derive(
        unlock: UnlockStatus.unavailable,
        purchasedAt: now.add(const Duration(minutes: 1)),
      );
      expect(a.entitled, isFalse);
      expect(a.source, AccessSource.none);
    });

    test('warns from day 5 of an unverified trial, with days remaining', () {
      final a = derive(
        trial: trialStartedAgo(
          const Duration(days: 1),
          verifiedAgo: const Duration(days: 5, hours: 1),
        ),
      );
      expect(a.entitled, isTrue);
      expect(a.cacheGoingStale, isTrue);
      expect(a.graceDaysLeft, 1);
    });

    test('says nothing while the trial check is fresh', () {
      final a = derive(
        trial: trialStartedAgo(
          const Duration(days: 1),
          verifiedAgo: const Duration(hours: 2),
        ),
      );
      expect(a.cacheGoingStale, isFalse);
    });

    test('an unverified trial lapses once past the grace window', () {
      // The anti-piracy half of §3.5: airplane mode plus a rolled-back clock
      // used to keep an "active" trial alive forever, because the phase was
      // pure arithmetic against the local clock. Seven days with no successful
      // server check now locks it, exactly as a cached purchase locks.
      final a = derive(
        trial: trialStartedAgo(
          const Duration(days: 1),
          verifiedAgo: const Duration(days: 7, minutes: 1),
        ),
      );
      expect(a.entitled, isFalse);
      expect(a.source, AccessSource.none);
    });

    test('and survives right up to the edge of it', () {
      final a = derive(
        trial: trialStartedAgo(
          const Duration(days: 1),
          verifiedAgo: const Duration(days: 6, hours: 23),
        ),
      );
      expect(a.entitled, isTrue);
      expect(a.source, AccessSource.trial);
    });

    test(
      'a trial never yet verified is honoured — dead zone, not a cracker',
      () {
        // First launch with no network: startedAt from cache, verifiedAt null.
        // Locking here punishes the one driver who cannot fix it.
        final a = derive(trial: trialStartedAgo(const Duration(days: 1)));
        expect(a.entitled, isTrue);
        expect(a.source, AccessSource.trial);
      },
    );
  });

  group('tester build kill date (§6)', () {
    test('past the kill date everything locks, trial or not', () {
      final a = derive(
        trial: trialStartedAgo(const Duration(days: 1)),
        buildExpiry: now.subtract(const Duration(days: 1)),
      );
      expect(a.entitled, isFalse);
    });

    test('a purchase does not survive it either — the build is dead', () {
      final a = derive(
        unlock: UnlockStatus.purchased,
        buildExpiry: now.subtract(const Duration(days: 1)),
      );
      expect(a.entitled, isFalse);
    });

    test('before the date it changes nothing', () {
      final a = derive(
        trial: trialStartedAgo(const Duration(days: 1)),
        buildExpiry: now.add(const Duration(days: 30)),
      );
      expect(a.entitled, isTrue);
    });

    test('locks exactly at the kill-date boundary', () {
      final a = derive(unlock: UnlockStatus.purchased, buildExpiry: now);
      expect(a.entitled, isFalse);
    });
  });

  group('debug unlock (§6.2)', () {
    test('forces entitlement with neither Play nor a trial', () {
      final a = Access.derive(
        unlock: UnlockStatus.unavailable,
        trial: TrialState.initial,
        now: now,
        purchasedAt: null,
        debugUnlocked: true,
      );
      expect(a.entitled, isTrue);
      expect(a.source, AccessSource.debugBuild);
    });
  });
}
