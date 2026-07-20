import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fox_settings.dart';
import '../domain/offer_summary.dart';
import '../domain/verdict.dart';
import '../ui/home/dashboard_state.dart' show Tally;
import '../ui/settings/settings_controller.dart';

/// The persisted offer log — every scored offer FoxyCo has seen.
///
/// State is the full list, newest first. Backed by a single SharedPreferences
/// JSON blob: at MVP volume (tens of offers a day, capped at [maxEntries])
/// that's a few hundred KB worst case, well under any prefs limit, and it
/// avoids dragging in a database for what is still an append-only log. If
/// volume ever outgrows this, swap the load/save internals for Drift — the
/// provider surface stays the same.
///
/// Off-device (widget tests) the prefs channel isn't registered; loads fail
/// soft to an empty log and saves are best-effort, so tests just see [].
class OfferLog extends Notifier<List<OfferSummary>> {
  static const _prefsKey = 'foxyco.offer_log.v1';

  /// Hard cap so the blob can't grow unbounded if the driver keeps
  /// "forever" retention. Oldest entries fall off first.
  static const maxEntries = 2000;

  @override
  List<OfferSummary> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(OfferSummary.fromJson)
          .toList()
        ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
      state = list;
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo offer log load skipped: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((o) => o.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo offer log save skipped: $e');
    }
  }

  /// Append a freshly scored offer (newest first) and persist. Retention is
  /// enforced here too — cheap, and it means old entries age out as new ones
  /// arrive without a startup purge racing the async settings load.
  void record(OfferSummary offer) {
    var next = [offer, ...state.take(maxEntries - 1)];
    final days = ref.read(settingsProvider).retentionDays;
    if (days != FoxSettings.keepForever) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      next = next.where((o) => o.seenAt.isAfter(cutoff)).toList();
    }
    state = next;
    _save();
  }

  /// Drop entries older than [days] (retention purge). Returns removed count.
  int purgeOlderThan(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final before = state.length;
    state = state.where((o) => o.seenAt.isAfter(cutoff)).toList();
    final removed = before - state.length;
    if (removed > 0) _save();
    return removed;
  }

  /// Wipe the whole log (Settings "clear history").
  void clearAll() {
    state = const [];
    _save();
  }
}

final offerLogProvider = NotifierProvider<OfferLog, List<OfferSummary>>(
  OfferLog.new,
);

/// Today's good/ok/bad counts, derived live from the log.
final todayTallyProvider = Provider<Tally>((ref) {
  final log = ref.watch(offerLogProvider);
  final now = DateTime.now();
  return _tallyFor(log, now);
});

/// Yesterday's counts — feeds the "vs yesterday" trend chip on Home.
final yesterdayTallyProvider = Provider<Tally>((ref) {
  final log = ref.watch(offerLogProvider);
  final y = DateTime.now().subtract(const Duration(days: 1));
  return _tallyFor(log, y);
});

Tally _tallyFor(List<OfferSummary> log, DateTime day) {
  var good = 0, ok = 0, bad = 0;
  for (final o in log) {
    final t = o.seenAt;
    if (t.year != day.year || t.month != day.month || t.day != day.day) {
      continue;
    }
    switch (o.verdict) {
      case Verdict.good:
        good++;
      case Verdict.ok:
        ok++;
      case Verdict.bad:
        bad++;
      case Verdict.unknown:
        break;
    }
  }
  return Tally(good: good, ok: ok, bad: bad);
}

/// The most recent logged offer, or null when the log is empty.
final lastOfferProvider = Provider<OfferSummary?>((ref) {
  final log = ref.watch(offerLogProvider);
  return log.isEmpty ? null : log.first;
});
