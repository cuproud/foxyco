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
    double totalKm = 11.7,
    String? category = 'Share',
    GigPlatform platform = GigPlatform.uber,
  }) => OfferSummary(
    platform: platform,
    verdict: Verdict.bad,
    payout: payout,
    totalKm: totalKm,
    totalMinutes: 24,
    seenAt: seenAt,
    category: category,
  );

  final t = DateTime(2026, 7, 26, 14, 49);

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

  test('a genuinely different offer inside the window still records', () {
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

    l.record(
      offer(seenAt: t.add(const Duration(seconds: 3)), category: 'UberX'),
    );
    expect(l.state, hasLength(4));
  });

  test('only the newest entry is compared — no scan of the whole log', () {
    final l = log();
    l.record(offer(seenAt: t));
    l.record(offer(seenAt: t.add(const Duration(seconds: 1)), payout: 4.18));
    // Matches the entry two back, but the one in front of it differs, so this
    // is the card coming round again rather than a flicker. Records.
    l.record(offer(seenAt: t.add(const Duration(seconds: 2))));
    expect(l.state, hasLength(3));
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
