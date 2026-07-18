import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/driver_profile.dart';

/// Holds the driver profile, persisted as one SharedPreferences JSON blob
/// (`foxyco.profile.v1`) — same live-apply pattern as [SettingsController]:
/// every setter saves immediately, no explicit save button.
class ProfileController extends Notifier<DriverProfile> {
  static const _prefsKey = 'foxyco.profile.v1';

  @override
  DriverProfile build() {
    _load();
    return DriverProfile.empty;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = DriverProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo profile load skipped: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo profile save skipped: $e');
    }
  }

  void _set(DriverProfile next) {
    state = next;
    _save();
  }

  void setName(String v) => _set(state.copyWith(name: v));
  void setMake(String v) => _set(state.copyWith(vehicleMake: v));
  void setModel(String v) => _set(state.copyWith(vehicleModel: v));
  void setYear(String v) => _set(state.copyWith(vehicleYear: v));
  void setPlate(String v) => _set(state.copyWith(licensePlate: v));
  void setColor(int v) => _set(state.copyWith(vehicleColor: v));
  void setType(VehicleType v) => _set(state.copyWith(vehicleType: v));
}

final profileProvider = NotifierProvider<ProfileController, DriverProfile>(
  ProfileController.new,
);
