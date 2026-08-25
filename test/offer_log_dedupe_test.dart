import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedOfferLog extends OfferLog {
  final loadPreferences = Completer<SharedPreferences>();
  var _firstRead = true;

  @override
  Future<SharedPreferences> preferences() {
    if (_firstRead) {
      _firstRead = false;
      return loadPreferences.future;
    }
    return SharedPreferences.getInstance();
  }
}

/// Device 2026-07-26: History showed two identical
/// "Uber · Share · $10.19 · 11.7 km · 2:49 PM" rows. OfferWatcher drops
/// `_shownKey` whenever a frame stops looking like the card, so a card that
/// flickers and comes back parses as brand new and gets logged twice — and every
/// stat downstream counts one offer as two.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Off-device SharedPreferences isn't registered; the log loads/saves soft, so
  // build() starts empty and record() works in memory. That's all this needs.
  OfferLog log() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(offerLogProvider); // force build
    return container.read(offerLogProvider.notifier);
  }

  OfferSummary offer({
    required DateTime seenAt,
    double payout = 10.19,
    double bonus = 0,
    double totalKm = 11.7,
    String? category = 'Share',
    GigPlatform platform = GigPlatform.uber,
    OfferOutcome outcome = OfferOutcome.unknown,
    double? finalPayout,
  }) => OfferSummary(
    platform: platform,
    verdict: Verdict.bad,
    payout: payout,
    finalPayout: finalPayout,
    bonus: bonus,
    totalKm: totalKm,
    totalMinutes: 24,
    seenAt: seenAt,
    category: category,
    outcome: outcome,
  );

  final t = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
  );

  test('the same card logged twice a second apart records once', () {
    final l = log();
    l.record(offer(seenAt: t));
    l.record(offer(seenAt: t.add(const Duration(seconds: 1))));
    expect(l.state, hasLength(1));
    expect(l.state.single.seenAt, t, reason: 'keeps the FIRST sighting');
  });

  test('the same card again after the window is a new offer', () {
    final l = log();
    l.record(offer(seenAt: t));
    l.record(offer(seenAt: t.add(OfferLog.dedupeWindow)));
    expect(l.state, hasLength(2));
  });

  test('a confirmed card exit allows identical next-offer values', () {
    final l = log();
    l.record(offer(seenAt: t));
    l.record(
      offer(seenAt: t.add(const Duration(seconds: 1))),
      confirmedNewCard: true,
    );
    expect(l.state, hasLength(2));
  });

  test('different economics or platform inside the window still record', () {
    final l = log();
    l.record(offer(seenAt: t));
    // One cent apart is enough — the guard compares what the parser read.
    l.record(offer(seenAt: t.add(const Duration(seconds: 1)), payout: 10.20));
    expect(l.state, hasLength(2));

    l.record(
      offer(
        seenAt: t.add(const Duration(seconds: 2)),
        platform: GigPlatform.lyft,
      ),
    );
    expect(l.state, hasLength(3));

    expect(l.state, hasLength(3));
  });

  test('an interleaved app frame cannot duplicate an earlier live card', () {
    final l = log();
    l.record(offer(seenAt: t));
    l.record(offer(seenAt: t.add(const Duration(seconds: 1)), payout: 4.18));
    // Matches the entry two back. Accessibility windows can interleave reads,
    // so it remains the same card until a positive card exit says otherwise.
    l.record(offer(seenAt: t.add(const Duration(seconds: 2))));
    expect(l.state, hasLength(2));
  });

  test('an accepted Lyft ride cannot be re-added with settled distance', () {
    final l = log();
    final now = DateTime.now();
    final accepted = l.record(
      offer(
        seenAt: now,
        platform: GigPlatform.lyft,
        payout: 8.01,
        bonus: 1.04,
        totalKm: 10.1,
      ),
    );
    expect(l.markOutcome(accepted, OfferOutcome.taken), isTrue);

    l.record(
      offer(
        seenAt: now.add(const Duration(seconds: 10)),
        platform: GigPlatform.lyft,
        payout: 8.01,
        bonus: 1.04,
        totalKm: 11.5,
      ),
      confirmedNewCard: true,
    );

    expect(l.state, hasLength(1));
  });

  test(
    'saved accepted Lyft duplicates collapse to the final-payout row',
    () async {
      final original = offer(
        seenAt: t,
        platform: GigPlatform.lyft,
        payout: 8.01,
        bonus: 1.04,
        totalKm: 10.1,
        outcome: OfferOutcome.taken,
      );
      final updated = offer(
        seenAt: t.add(const Duration(seconds: 10)),
        platform: GigPlatform.lyft,
        payout: 8.01,
        bonus: 1.04,
        totalKm: 11.5,
        outcome: OfferOutcome.taken,
        finalPayout: 9.06,
      );
      SharedPreferences.setMockInitialValues({
        'foxyco.offer_log.v1': jsonEncode([
          original.toJson(),
          updated.toJson(),
        ]),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(offerLogProvider);
      while (container.read(offerLogProvider).isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(container.read(offerLogProvider), hasLength(1));
      expect(container.read(offerLogProvider).single.finalPayout, 9.06);
      expect(container.read(offerLogProvider).single.totalKm, 11.5);
    },
  );

  test('late labels still identify the same card', () {
    final l = log();
    l.record(offer(seenAt: t, category: null));
    l.record(
      OfferSummary(
        platform: GigPlatform.uber,
        verdict: Verdict.bad,
        payout: 10.19,
        bonus: 2,
        totalKm: 11.7,
        totalMinutes: 24,
        seenAt: t.add(const Duration(seconds: 1)),
        category: 'Share',
        isQueued: true,
      ),
    );
    expect(l.state, hasLength(1));
  });

  test('sameCardAs ignores when we saw it, and our own verdict', () {
    final a = offer(seenAt: t);
    final b = OfferSummary(
      platform: a.platform,
      verdict: Verdict.good, // ours, not the card's
      payout: a.payout,
      totalKm: a.totalKm,
      totalMinutes: a.totalMinutes,
      seenAt: t.add(const Duration(hours: 3)),
      outcome: OfferOutcome.taken, // also ours
      category: a.category,
    );
    expect(a.sameCardAs(b), isTrue);
  });

  test('repeated trip frames update one exact offer only', () {
    final l = log();
    final now = DateTime.now();
    final smaller = l.record(
      offer(seenAt: now.subtract(const Duration(seconds: 20)), payout: 5.36),
    );
    final accepted = l.record(
      offer(seenAt: now.subtract(const Duration(seconds: 5)), payout: 19.94),
    );

    expect(l.markOutcome(accepted, OfferOutcome.taken), isTrue);
    expect(l.markOutcome(accepted, OfferOutcome.taken), isFalse);
    expect(l.state.map((o) => o.outcome), [
      OfferOutcome.taken,
      OfferOutcome.unknown,
    ]);
    expect(smaller.outcome, OfferOutcome.unknown);
  });

  test(
    'manual correction works after inference window and cannot be overwritten',
    () {
      final l = log();
      final candidate = l.record(
        offer(
          seenAt: DateTime.now().subtract(const Duration(minutes: 3)),
          payout: 17.06,
        ),
      );

      expect(l.setOutcome(candidate, OfferOutcome.missed), isTrue);
      expect(l.state.single.outcomeIsManual, isTrue);
      expect(l.markOutcome(candidate, OfferOutcome.taken), isFalse);
      expect(l.state.single.outcome, OfferOutcome.missed);
    },
  );

  test('final payout preserves upfront offer and survives JSON', () {
    final l = log();
    final upfront = l.record(offer(seenAt: t, payout: 19.70, totalKm: 14.1));

    expect(l.setFinalPayout(upfront, 22.26), isTrue);
    final updated = l.state.single;
    expect(updated.payout, 19.70);
    expect(updated.finalPayout, 22.26);
    expect(updated.effectivePricePerKm, closeTo(22.26 / 14.1, 1e-9));

    final restored = OfferSummary.fromJson(updated.toJson());
    expect(restored.payout, 19.70);
    expect(restored.finalPayout, 22.26);
    expect(l.setFinalPayout(updated, null), isTrue);
    expect(l.state.single.effectivePayout, 19.70);
  });

  test('offer received during hydration survives with disk history', () async {
    final stored = offer(seenAt: t.subtract(const Duration(hours: 1)));
    SharedPreferences.setMockInitialValues({
      'foxyco.offer_log.v1': jsonEncode([stored.toJson()]),
    });
    final container = ProviderContainer(
      overrides: [offerLogProvider.overrideWith(_DelayedOfferLog.new)],
    );
    addTearDown(container.dispose);
    container.read(offerLogProvider);
    final log = container.read(offerLogProvider.notifier) as _DelayedOfferLog;
    final live = offer(seenAt: t, payout: 12.34, platform: GigPlatform.lyft);

    log.record(live);
    log.loadPreferences.complete(await SharedPreferences.getInstance());
    while (container.read(offerLogProvider).length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final prefs = await SharedPreferences.getInstance();
    while ((jsonDecode(prefs.getString('foxyco.offer_log.v1')!)
                as List<dynamic>)
            .length <
        2) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(offerLogProvider), [live, isA<OfferSummary>()]);
    expect(container.read(offerLogProvider).last.payout, stored.payout);
    expect(
      (jsonDecode(prefs.getString('foxyco.offer_log.v1')!) as List<dynamic>),
      hasLength(2),
    );
  });

  test('malformed saved row does not discard valid offer history', () async {
    final stored = offer(seenAt: t);
    SharedPreferences.setMockInitialValues({
      'foxyco.offer_log.v1': jsonEncode([
        {'seenAt': 'not-a-date'},
        stored.toJson(),
      ]),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(offerLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(container.read(offerLogProvider).single.seenAt, t);
  });
}
