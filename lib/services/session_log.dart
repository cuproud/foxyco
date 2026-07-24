import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_summary.dart';

/// Completed watch sessions, newest first — same prefs-blob pattern as
/// [OfferLog], just far lower volume (a handful per day at most).
class SessionLog extends Notifier<List<SessionSummary>> {
  static const _prefsKey = 'foxyco.session_log.v1';

  /// Plenty for "last session" plus any future history view.
  static const maxEntries = 100;

  @override
  List<SessionSummary> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(SessionSummary.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo session log load skipped: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo session log save skipped: $e');
    }
  }

  void record(SessionSummary session) {
    state = [session, ...state.take(maxEntries - 1)];
    _save();
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
