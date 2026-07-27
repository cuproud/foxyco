import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/offer_log.dart';

/// Device 2026-07-26: History showed two identical
/// "Uber · Share · $10.19 · 11.7 km · 2:49 PM" rows. OfferWatcher drops
/// `_shownKey` whenever a frame stops looking like the card, so a card that
/// flickers and comes back parses as brand new and gets logged twice — and every
/// stat downstream counts one offer as two.
void main() {
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
      offer(seenAt: t.add(const Duration(seconds: 2)), platform: GigPlatform.lyft),
    );
    expect(l.state, hasLength(3));

    l.record(offer(seenAt: t.add(const Duration(seconds: 3)), category: 'UberX'));
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
}
