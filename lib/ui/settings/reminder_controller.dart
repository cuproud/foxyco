import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/car_reminder.dart';

/// Car reminders, persisted as one SharedPreferences JSON list (same pattern
/// as the garage). Sorted soonest-first.
class ReminderController extends Notifier<List<CarReminder>> {
  static const prefsKey = 'foxyco.reminders.v1';
  final Completer<void> _ready = Completer<void>();
  final List<List<CarReminder> Function(List<CarReminder>)> _pending = [];
  bool _hydrated = false;

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @override
  List<CarReminder> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await preferences();
      final raw = prefs.getString(prefsKey);
      var loaded = raw == null
          ? <CarReminder>[]
          : (jsonDecode(raw) as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(CarReminder.fromJson)
                .toList();
      for (final change in _pending) {
        loaded = change(loaded);
      }
      if (ref.mounted) state = _sorted(loaded);
    } catch (_) {
      // Corrupt blob → start empty rather than crash Settings.
    } finally {
      _hydrated = true;
      _pending.clear();
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _save() async {
    try {
      await _ready.future;
      if (!ref.mounted) return;
      final prefs = await preferences();
      await prefs.setString(
        prefsKey,
        jsonEncode([for (final r in state) r.toJson()]),
      );
    } catch (_) {}
  }

  static List<CarReminder> _sorted(List<CarReminder> list) =>
      [...list]..sort((a, b) => a.date.compareTo(b.date));

  void _change(List<CarReminder> Function(List<CarReminder>) change) {
    if (!_hydrated) _pending.add(change);
    state = _sorted(change(state));
    unawaited(_save());
  }

  void add(CarReminder r) {
    _change((current) => [...current, r]);
  }

  void update(CarReminder r) {
    _change(
      (current) => [
        for (final e in current)
          if (e.id == r.id) r else e,
      ],
    );
  }

  void remove(String id) {
    _change(
      (current) => [
        for (final e in current)
          if (e.id != id) e,
      ],
    );
  }
}

final reminderProvider =
    NotifierProvider<ReminderController, List<CarReminder>>(
      ReminderController.new,
    );

/// Reminders currently inside their lead window (or overdue), soonest first —
/// the Home banner shows the first of these.
final dueRemindersProvider = Provider<List<CarReminder>>(
  (ref) => ref.watch(reminderProvider).where((r) => r.isDue()).toList(),
);
