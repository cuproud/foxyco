import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fox_settings.dart';
import '../domain/offer_summary.dart';
import '../domain/platform.dart';
import '../domain/rate_mode.dart';
import '../domain/thresholds.dart';
import '../domain/verdict.dart';
import '../domain/decision_engine.dart';
import 'fox_log.dart';
import 'history_backup.dart';
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
  final Completer<void> _loaded = Completer<void>();

  Future<void> get ready => _loaded.future;

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @override
  List<OfferSummary> build() {
    // A queued write must not outlive the container (widget tests dispose it at
    // tear-down, and a stray timer there is a test failure, not a nicety).
    ref.onDispose(() {
      if (_saveTimer != null) {
        _saveTimer!.cancel();
        _saveTimer = null;
        _save();
      }
    });
    _load();
    return const [];
  }

  /// Pending coalesced write, or null when the log is already on disk.
  Timer? _saveTimer;

  /// How long writes are held so a burst becomes one encode.
  static const _saveDebounce = Duration(seconds: 3);

  Future<void> _load() async {
    try {
      final prefs = await preferences();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = <OfferSummary>[];
      var droppedRow = false;
      for (final row in jsonDecode(raw) as List<dynamic>) {
        try {
          if (row is! Map<String, dynamic>) throw const FormatException();
          list.add(OfferSummary.fromJson(row));
        } catch (_) {
          droppedRow = true;
        }
      }
      list.sort((a, b) => b.seenAt.compareTo(a.seenAt));
      if (!ref.mounted) return;
      if (droppedRow) {
        ref
            .read(foxLogProvider)
            .log('offer-log', 'skipped malformed saved row');
      }
      // A real accessibility event can arrive while preferences are loading.
      // Keep those live rows and fold the older disk history behind them.
      state = [...state, ...list]..sort((a, b) => b.seenAt.compareTo(a.seenAt));
      final beforeDedupe = state.length;
      state = _collapseOcrCorrections(_collapseAcceptedDuplicates(state));
      if (state.length > maxEntries) {
        state = state.take(maxEntries).toList();
      }
      if (state.length < beforeDedupe) {
        await prefs.setString(
          _prefsKey,
          jsonEncode(state.map((o) => o.toJson()).toList()),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo offer log load skipped: $e');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  /// Queue a write instead of making one now.
  ///
  /// Persisting is a full `jsonEncode` of the whole list — up to [maxEntries]
  /// rows — and a scored offer writes TWICE in quick succession: once when it
  /// lands, once when [markLatestOutcome] stamps take/pass on it. Coalescing
  /// turns that pair, and any burst of offers, into a single encode. State is
  /// already updated in memory, so nothing the driver can see waits on this.
  ///
  /// Destructive edits (clear, purge) call [_save] directly — those must be on
  /// disk before the driver can close the app and doubt they happened.
  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      _save();
    });
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      // Never replace the disk blob with a partial pre-hydration state.
      await _loaded.future;
      if (!ref.mounted) return;
      final prefs = await preferences();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((o) => o.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo offer log save skipped: $e');
    }
  }

  Future<void> _writeSnapshot(List<OfferSummary> entries) async {
    await _loaded.future;
    if (!ref.mounted) throw StateError('Offer history is no longer active.');
    final prefs = await preferences();
    if (!await prefs.setString(
      _prefsKey,
      jsonEncode(entries.map((o) => o.toJson()).toList()),
    )) {
      throw StateError('Offer history could not be saved.');
    }
  }

  /// Restores a validated backup as one atomic state transition.
  Future<HistoryImportResult> importHistory(
    List<OfferSummary> imported, {
    HistoryImportMode mode = HistoryImportMode.merge,
  }) async {
    await _loaded.future;
    _saveTimer?.cancel();
    _saveTimer = null;
    final previous = state;
    final next = mode == HistoryImportMode.replace
        ? imported.take(maxEntries).toList()
        : _mergeHistory(previous, imported);
    next.sort((a, b) => b.seenAt.compareTo(a.seenAt));
    final added = next.length - previous.length;
    state = next;
    try {
      await _writeSnapshot(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
    return HistoryImportResult(
      imported: imported.length,
      added: mode == HistoryImportMode.replace ? next.length : added,
      total: next.length,
    );
  }

  static List<OfferSummary> _mergeHistory(
    List<OfferSummary> local,
    List<OfferSummary> imported,
  ) {
    final result = [...local];
    for (final incoming in imported) {
      final index = result.indexWhere(
        (existing) =>
            existing.seenAt == incoming.seenAt && existing.sameCardAs(incoming),
      );
      if (index < 0) {
        result.add(incoming);
        continue;
      }
      final existing = result[index];
      result[index] = OfferSummary(
        platform: existing.platform,
        verdict: existing.verdict == Verdict.unknown
            ? incoming.verdict
            : existing.verdict,
        payout: existing.payout,
        finalPayout: existing.finalPayout ?? incoming.finalPayout,
        bonus: existing.bonus == 0 ? incoming.bonus : existing.bonus,
        tip: existing.finalPayout != null ? existing.tip : incoming.tip,
        tollReimbursement: existing.finalPayout != null
            ? existing.tollReimbursement
            : incoming.tollReimbursement,
        pickupKm: existing.pickupKm,
        totalKm: existing.totalKm,
        totalMinutes: existing.totalMinutes,
        seenAt: existing.seenAt,
        outcome: existing.outcomeIsManual
            ? existing.outcome
            : incoming.outcomeIsManual
            ? incoming.outcome
            : existing.outcome == OfferOutcome.unknown
            ? incoming.outcome
            : existing.outcome,
        outcomeIsManual: existing.outcomeIsManual || incoming.outcomeIsManual,
        detectedOutcome: existing.detectedOutcome ?? incoming.detectedOutcome,
        scoringSnapshot: existing.scoringSnapshot ?? incoming.scoringSnapshot,
        category: existing.category ?? incoming.category,
        isQueued: existing.isQueued || incoming.isQueued,
        deliveryCount: existing.deliveryCount,
        itemCount: existing.itemCount,
        unitCount: existing.unitCount,
      );
    }
    if (result.length > maxEntries) return result.take(maxEntries).toList();
    return result;
  }

  /// How long the same card stays "the offer we already logged". Covers a full
  /// flicker cycle (clear grace + a re-parse) with room to spare, while staying
  /// short enough that a genuinely new offer can't be swallowed — it would have
  /// to match platform, payout, both distances, duration AND tier, to the cent
  /// and the metre, inside two minutes.
  static const dedupeWindow = Duration(minutes: 2);

  static bool _isAccepted(OfferSummary offer) =>
      offer.outcome == OfferOutcome.taken ||
      offer.outcome == OfferOutcome.completed;

  static bool _sameAcceptedTrip(OfferSummary a, OfferSummary b) =>
      _isAccepted(a) &&
      _isAccepted(b) &&
      a.platform == b.platform &&
      a.payout == b.payout &&
      a.bonus == b.bonus &&
      a.isQueued == b.isQueued &&
      a.seenAt.difference(b.seenAt).abs() < dedupeWindow;

  static List<OfferSummary> _collapseAcceptedDuplicates(
    List<OfferSummary> offers,
  ) {
    final result = <OfferSummary>[];
    for (final offer in offers) {
      final duplicate = result.indexWhere(
        (seen) => _sameAcceptedTrip(seen, offer),
      );
      if (duplicate < 0) {
        result.add(offer);
      } else if (result[duplicate].finalPayout == null &&
          offer.finalPayout != null) {
        result[duplicate] = offer;
      }
    }
    return result;
  }

  static bool _sameLikelyOcrCorrection(OfferSummary a, OfferSummary b) {
    final smaller = a.payout < b.payout ? a.payout : b.payout;
    final larger = a.payout < b.payout ? b.payout : a.payout;
    return a.platform == GigPlatform.uber &&
        b.platform == GigPlatform.uber &&
        ((larger - smaller * 100).abs() < 0.001 ||
            (a.payout - a.pickupKm).abs() < 0.001 ||
            (b.payout - b.pickupKm).abs() < 0.001) &&
        a.pickupKm == b.pickupKm &&
        a.totalKm == b.totalKm &&
        a.totalMinutes == b.totalMinutes &&
        a.deliveryCount == b.deliveryCount &&
        a.seenAt.difference(b.seenAt).abs() < const Duration(seconds: 30);
  }

  static List<OfferSummary> _collapseOcrCorrections(List<OfferSummary> offers) {
    final result = <OfferSummary>[];
    for (final offer in offers) {
      final duplicate = result.indexWhere(
        (seen) => _sameLikelyOcrCorrection(seen, offer),
      );
      if (duplicate < 0) {
        result.add(offer);
      } else {
        final seen = result[duplicate];
        final seenIsDistance = (seen.payout - seen.pickupKm).abs() < 0.001;
        final offerIsDistance = (offer.payout - offer.pickupKm).abs() < 0.001;
        if (seenIsDistance || !offerIsDistance && offer.payout < seen.payout) {
          result[duplicate] = offer;
        }
      }
    }
    return result;
  }

  /// Append a freshly scored offer (newest first) and persist. Retention is
  /// enforced here too — cheap, and it means old entries age out as new ones
  /// arrive without a startup purge racing the async settings load.
  OfferSummary record(OfferSummary offer, {bool confirmedNewCard = false}) {
    // Same card, twice. OfferWatcher clears `_shownKey` whenever a frame stops
    // looking like the card (a partial read, a half-rendered tree), so a card
    // that flickers and comes back parses as brand new and lands here a second
    // time — two identical rows a second apart, and every stat downstream
    // (tally, $/km average, busiest hour) counting one offer as two. Device
    // 2026-07-26: two "Uber Share · $10.19 · 11.7 km · 2:49 PM" rows.
    //
    // Guarding here rather than in the watcher on purpose: re-showing the PILL
    // for a card that came back is correct, and this is the one sink every
    // caller of the log routes through.
    if (!confirmedNewCard) {
      for (final seen in state) {
        if (seen.sameCardAs(offer) &&
            offer.seenAt.difference(seen.seenAt).abs() < dedupeWindow) {
          return seen;
        }
      }
    }
    // After acceptance Lyft can expose a second snapshot of the same ride with
    // settled distance details. It is not another offer; queued rides remain
    // distinct through [isQueued].
    for (final seen in state) {
      if (_isAccepted(seen) &&
          seen.platform == offer.platform &&
          seen.payout == offer.payout &&
          seen.bonus == offer.bonus &&
          seen.isQueued == offer.isQueued &&
          offer.seenAt.difference(seen.seenAt).abs() < dedupeWindow) {
        return seen;
      }
    }
    var next = [offer, ...state.take(maxEntries - 1)];
    final days = ref.read(settingsProvider).retentionDays;
    if (days != FoxSettings.keepForever) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      next = next.where((o) => o.seenAt.isAfter(cutoff)).toList();
    }
    state = next;
    // A real offer is valuable data. Start the write now; only the likely
    // follow-up outcome stamp is debounced. If hydration is still running,
    // [_save] waits for it and persists the merged list.
    unawaited(_save());
    return offer;
  }

  /// Stamp the exact offer that produced the follow-up screen. Repeated
  /// accessibility frames therefore update one row instead of walking backward
  /// through every unresolved offer from the same app.
  bool markOutcome(
    OfferSummary candidate,
    OfferOutcome outcome, {
    bool includeQueued = false,
    bool manual = false,
  }) {
    final index = state.indexWhere(
      (offer) =>
          offer.seenAt == candidate.seenAt &&
          offer.sameCardAs(candidate) &&
          (manual || !offer.outcomeIsManual) &&
          !(outcome == OfferOutcome.taken &&
              offer.isQueued &&
              !includeQueued) &&
          (manual ||
              offer.outcome == OfferOutcome.unknown ||
              outcome == OfferOutcome.taken &&
                  offer.outcome == OfferOutcome.missed) &&
          (manual ||
              DateTime.now().difference(offer.seenAt).abs() < dedupeWindow),
    );
    if (index < 0) return false;
    state = [
      ...state.take(index),
      state[index].withOutcome(outcome, manual: manual),
      ...state.skip(index + 1),
    ];
    _saveSoon();
    return true;
  }

  /// Driver corrections are ground truth and automation must not overwrite them.
  bool setOutcome(OfferSummary offer, OfferOutcome outcome) =>
      markOutcome(offer, outcome, includeQueued: true, manual: true);

  /// Set realized earnings without rewriting the original offer or verdict.
  bool setFinalPayout(
    OfferSummary offer,
    double? value, {
    double tip = 0,
    double tollReimbursement = 0,
  }) {
    if (value != null &&
        (!value.isFinite ||
            value <= 0 ||
            !tip.isFinite ||
            tip < 0 ||
            !tollReimbursement.isFinite ||
            tollReimbursement < 0 ||
            tip + tollReimbursement > value)) {
      return false;
    }
    final index = state.indexWhere(
      (candidate) =>
          candidate.seenAt == offer.seenAt && candidate.sameCardAs(offer),
    );
    if (index < 0) return false;
    state = [
      ...state.take(index),
      state[index].withFinalPayout(
        value,
        tip: value == null ? 0 : tip,
        tollReimbursement: value == null ? 0 : tollReimbursement,
      ),
      ...state.skip(index + 1),
    ];
    _saveSoon();
    return true;
  }

  /// Correct a parser/OCR distance without deleting the history row. This is
  /// deliberately available for every platform: Accessibility selectors can
  /// change too, even though the first reported decimal loss came from Uber OCR.
  bool setTotalDistance(OfferSummary offer, double totalKm) {
    if (!totalKm.isFinite || totalKm <= 0 || totalKm < offer.pickupKm) {
      return false;
    }
    final index = state.indexWhere(
      (candidate) =>
          candidate.seenAt == offer.seenAt &&
          candidate.platform == offer.platform,
    );
    if (index < 0) return false;
    final current = state[index];
    final snapshot = current.scoringSnapshot;
    var verdict = current.verdict;
    if (snapshot != null) {
      if (snapshot.minimumPayoutEnabled &&
          current.payout < snapshot.minimumPayout) {
        verdict = Verdict.bad;
      } else {
        final hourly =
            snapshot.rateMode == RateMode.perHour && current.totalMinutes > 0;
        verdict = const DecisionEngine().evaluate(
          hourly ? current.pricePerHour : current.payout / totalKm,
          hourly
              ? Thresholds(
                  goodAtOrAbove: snapshot.goodPerHour,
                  badBelow: snapshot.badPerHour,
                )
              : Thresholds(
                  goodAtOrAbove: snapshot.goodPerKm,
                  badBelow: snapshot.badPerKm,
                ),
        );
      }
    }
    state = [
      ...state.take(index),
      current.withTotalKm(totalKm, correctedVerdict: verdict),
      ...state.skip(index + 1),
    ];
    _saveSoon();
    return true;
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
  Future<void> clearAll() async {
    await _loaded.future;
    state = const [];
    await _save();
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
