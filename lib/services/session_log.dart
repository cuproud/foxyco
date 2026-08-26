import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_summary.dart';
import '../domain/offer_summary.dart';
import 'fox_log.dart';

/// Completed watch sessions, newest first — same prefs-blob pattern as
/// [OfferLog], just far lower volume (a handful per day at most).
class SessionLog extends Notifier<List<SessionSummary>> {
  static const prefsKey = 'foxyco.session_log.v1';

  /// Plenty for "last session" plus any future history view.
  static const maxEntries = 100;
  final Completer<void> _loaded = Completer<void>();

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @override
  List<SessionSummary> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await preferences();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final saved = <SessionSummary>[];
      var droppedRow = false;
      for (final row in jsonDecode(raw) as List<dynamic>) {
        try {
          if (row is! Map<String, dynamic>) throw const FormatException();
          saved.add(SessionSummary.fromJson(row));
        } catch (_) {
          droppedRow = true;
        }
      }
      if (!ref.mounted) return;
      if (droppedRow) {
        ref
            .read(foxLogProvider)
            .log('session-log', 'skipped malformed saved row');
      }
      state = [...state, ...saved]
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      if (state.length > maxEntries) {
        state = state.take(maxEntries).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo session log load skipped: $e');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _save() async {
    try {
      await _loaded.future;
      if (!ref.mounted) return;
      final prefs = await preferences();
      await prefs.setString(
        prefsKey,
        jsonEncode(state.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo session log save skipped: $e');
    }
  }

  void record(SessionSummary session) {
    state = [session, ...state.take(maxEntries - 1)];
    unawaited(_save());
  }

  bool setActualEarnings(SessionSummary session, double? value) {
    final index = state.indexOf(session);
    if (index < 0) return false;
    final updated = session.withActualEarnings(value);
    final next = [...state];
    next[index] = updated;
    state = next;
    unawaited(_save());
    return true;
  }

  Future<void> clearAll() async {
    await _loaded.future;
    state = const [];
    await _save();
  }

  /// Rebuild the one saved session containing a corrected offer.
  Future<void> refreshForOffer(
    OfferSummary changed,
    List<OfferSummary> offers,
  ) async {
    await _loaded.future;
    if (!ref.mounted) return;
    state = [
      for (final session in state)
        if (!changed.seenAt.isBefore(session.startedAt) &&
            !changed.seenAt.isAfter(session.endedAt))
          SessionSummary.from(
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            offers: offers,
          ).withActualEarnings(session.actualEarnings)
        else
          session,
    ];
    await _save();
  }
}

final sessionLogProvider = NotifierProvider<SessionLog, List<SessionSummary>>(
  SessionLog.new,
);

/// The most recently completed session, or null before the first stop.
final lastSessionProvider = Provider<SessionSummary?>((ref) {
  final log = ref.watch(sessionLogProvider);
  return log.isEmpty ? null : log.first;
});
