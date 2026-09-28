import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/vehicle_expense.dart';

class VehicleExpenseController extends Notifier<List<VehicleExpense>> {
  static const prefsKey = 'foxyco.vehicle-expenses.v1';
  final Completer<void> _ready = Completer<void>();
  final List<List<VehicleExpense> Function(List<VehicleExpense>)> _pending = [];
  bool _hydrated = false;

  @protected
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  @override
  List<VehicleExpense> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await preferences();
      final raw = prefs.getString(prefsKey);
      var loaded = raw == null
          ? <VehicleExpense>[]
          : (jsonDecode(raw) as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(VehicleExpense.fromJson)
                .toList();
      for (final change in _pending) {
        loaded = change(loaded);
      }
      if (ref.mounted) state = _sorted(loaded);
    } catch (_) {
      // A corrupt local list should not prevent the Garage screen opening.
    } finally {
      _hydrated = true;
      _pending.clear();
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  static List<VehicleExpense> _sorted(List<VehicleExpense> items) =>
      [...items]..sort((a, b) => b.date.compareTo(a.date));

  void _change(List<VehicleExpense> Function(List<VehicleExpense>) change) {
    if (!_hydrated) _pending.add(change);
    state = _sorted(change(state));
    unawaited(_save());
  }

  Future<void> _save() async {
    await _ready.future;
    if (!ref.mounted) return;
    try {
      final prefs = await preferences();
      await prefs.setString(
        prefsKey,
        jsonEncode(state.map((expense) => expense.toJson()).toList()),
      );
    } catch (_) {}
  }

  void save(VehicleExpense expense) => _change(
    (current) => [
      for (final item in current)
        if (item.id != expense.id) item,
      expense,
    ],
  );

  void remove(String id) => _change(
    (current) => current.where((expense) => expense.id != id).toList(),
  );
}

final vehicleExpenseProvider =
    NotifierProvider<VehicleExpenseController, List<VehicleExpense>>(
      VehicleExpenseController.new,
    );
