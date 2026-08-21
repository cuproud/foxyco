import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/session_summary.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/session_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedSessionLog extends SessionLog {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup record merges with sessions still loading from disk', () async {
    final saved = SessionSummary(
      startedAt: DateTime(2026, 8, 6, 8),
      endedAt: DateTime(2026, 8, 6, 9),
    );
    final current = SessionSummary(
      startedAt: DateTime(2026, 8, 7, 8),
      endedAt: DateTime(2026, 8, 7, 9),
    );
    SharedPreferences.setMockInitialValues({
      SessionLog.prefsKey: jsonEncode([saved.toJson()]),
    });
    final container = ProviderContainer(
      overrides: [sessionLogProvider.overrideWith(_DelayedSessionLog.new)],
    );
    addTearDown(container.dispose);
    container.read(sessionLogProvider);
    final log =
        container.read(sessionLogProvider.notifier) as _DelayedSessionLog;

    log.record(current);
    log.loadPreferences.complete(await SharedPreferences.getInstance());
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final sessions = container.read(sessionLogProvider);
    expect(sessions.map((session) => session.startedAt), [
      current.startedAt,
      saved.startedAt,
    ]);
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(SessionLog.prefsKey)!;
    expect(persisted, contains('2026-08-07'));
    expect(persisted, contains('2026-08-06'));
  });

  test('malformed saved row does not discard valid session history', () async {
    final saved = SessionSummary(
      startedAt: DateTime(2026, 8, 6, 8),
      endedAt: DateTime(2026, 8, 6, 9),
    );
    SharedPreferences.setMockInitialValues({
      SessionLog.prefsKey: jsonEncode([
        {'startedAt': 'bad'},
        saved.toJson(),
      ]),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sessionLogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(
      container.read(sessionLogProvider).single.startedAt,
      saved.startedAt,
    );
  });

  test(
    'outcome correction refreshes session earnings without changing manual total',
    () async {
      SharedPreferences.setMockInitialValues({});
      final started = DateTime(2026, 8, 20, 8);
      final ended = DateTime(2026, 8, 20, 9);
      OfferSummary offer(DateTime seenAt, double payout) => OfferSummary(
        platform: GigPlatform.uber,
        verdict: Verdict.good,
        payout: payout,
        totalKm: 10,
        seenAt: seenAt,
        outcome: OfferOutcome.completed,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final log = container.read(sessionLogProvider.notifier);
      log.record(
        SessionSummary(
          startedAt: started,
          endedAt: ended,
          actualEarnings: 30,
          actualEarningsIsManual: true,
        ),
      );

      final corrected = offer(started.add(const Duration(minutes: 10)), 18);
      await log.refreshForOffer(corrected, [
        corrected,
        offer(ended.add(const Duration(minutes: 1)), 50),
      ]);

      final refreshed = container.read(sessionLogProvider).single;
      expect(refreshed.completed, 1);
      expect(refreshed.estimatedEarnings, 18);
      expect(refreshed.actualEarnings, 30);
      expect(refreshed.actualEarningsIsManual, isTrue);
    },
  );
}
