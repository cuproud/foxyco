import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../../services/fox_log.dart';

/// Holds the garage, persisted as one SharedPreferences JSON blob
/// (`foxyco.garage.v1`) — same fail-soft pattern as OfferLog. On first load,
/// if only the M5 single-profile blob exists, it's converted into a
/// one-vehicle garage (one-way, idempotent: once garage.v1 is written the
/// legacy key is never read again; it's kept on disk, harmless).
class GarageController extends Notifier<Garage> {
  static const prefsKey = 'foxyco.garage.v1';
  static const legacyKey = 'foxyco.profile.v1';

  @override
  Garage build() {
    _load();
    return Garage.empty;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        state = Garage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return;
      }
      final legacy = prefs.getString(legacyKey);
      if (legacy == null) return;
      final profile = DriverProfile.fromJson(
        jsonDecode(legacy) as Map<String, dynamic>,
      );
      final migrated = Garage.fromLegacyProfile(profile);
      state = migrated;
      if (migrated.vehicles.isNotEmpty) {
        await _save();
        ref
            .read(foxLogProvider)
            .log('garage', 'migrated profile.v1 → garage.v1');
      }
    } catch (e) {
      // Fail-soft: empty garage, never crash (spec M6 §10).
      ref.read(foxLogProvider).log('garage', 'load failed, starting empty: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'save skipped: $e');
    }
  }

  /// Editor Save — insert or update, persist (spec M6 §4.3).
  Future<void> saveVehicle(Vehicle v) async {
    state = state.upsert(v);
    await _save();
  }

  /// Delete — active falls to next remaining, last delete empties the garage.
  Future<void> deleteVehicle(String id) async {
    state = state.remove(id);
    await _save();
  }

  /// Garage card tap — instant, persisted (spec M6 §4.2).
  Future<void> setActive(String id) async {
    state = state.setActive(id);
    await _save();
  }
}

final garageProvider = NotifierProvider<GarageController, Garage>(
  GarageController.new,
);

/// The vehicle the hero card + art render. Null → hero hides.
final activeVehicleProvider = Provider<Vehicle?>(
  (ref) => ref.watch(garageProvider).active,
);

/// Driver name — the person, not the car (spec M6 §4.1). Own key; seeded from
/// the legacy profile's name on first run so nobody retypes it.
class DriverNameController extends Notifier<String> {
  static const prefsKey = 'foxyco.driver.v1';

  @override
  String build() {
    _load();
    return '';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null) {
        state = raw;
        return;
      }
      final legacy = prefs.getString(GarageController.legacyKey);
      if (legacy == null) return;
      final name = (jsonDecode(legacy) as Map<String, dynamic>)['name'];
      if (name is String && name.trim().isNotEmpty) {
        state = name;
        await prefs.setString(prefsKey, name);
      }
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'name load skipped: $e');
    }
  }

  /// Explicit save from the name card's check button (spec M6 §4.2 — no
  /// silent live-apply).
  Future<void> setName(String v) async {
    state = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, v);
    } catch (e) {
      ref.read(foxLogProvider).log('garage', 'name save skipped: $e');
    }
  }
}

final driverNameProvider = NotifierProvider<DriverNameController, String>(
  DriverNameController.new,
);
