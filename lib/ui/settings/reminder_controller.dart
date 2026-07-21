import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/car_reminder.dart';

/// Car reminders, persisted as one SharedPreferences JSON list (same pattern
/// as the garage). Sorted soonest-first.
class ReminderController extends Notifier<List<CarReminder>> {
  static const prefsKey = 'foxyco.reminders.v1';

  @override
  List<CarReminder> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(CarReminder.fromJson)
          .toList();
      state = _sorted(list);
    } catch (_) {
      // Corrupt blob → start empty rather than crash Settings.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        jsonEncode([for (final r in state) r.toJson()]),
      );
    } catch (_) {}
  }

  static List<CarReminder> _sorted(List<CarReminder> list) =>
      [...list]..sort((a, b) => a.date.compareTo(b.date));

  void add(CarReminder r) {
    state = _sorted([...state, r]);
    _save();
  }

  void update(CarReminder r) {
    state = _sorted([
      for (final e in state)
        if (e.id == r.id) r else e,
    ]);
    _save();
  }

  void remove(String id) {
    state = [
      for (final e in state)
        if (e.id != id) e,
    ];
    _save();
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
