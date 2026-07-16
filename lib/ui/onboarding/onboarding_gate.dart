import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run gate. One persisted bool decides whether the app boots into
/// `/onboarding` or straight to Home — read once in `main()` before `runApp`
/// so there's no flash of the wrong screen.
///
/// Off-device (widget tests) the prefs channel isn't registered; reads fail
/// soft to "not done" and writes are best-effort, matching SettingsController.
class OnboardingGate {
  const OnboardingGate._();

  static const _key = 'foxyco.onboarded.v1';

  /// Has the driver completed (or skipped past) onboarding before?
  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo onboarding read skipped: $e');
      return false;
    }
  }

  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo onboarding write skipped: $e');
    }
  }
}
