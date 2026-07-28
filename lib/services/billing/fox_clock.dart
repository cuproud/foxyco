import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The clock the trial and the offline grace window are measured against.
///
/// `DateTime.now()` alone is not good enough: winding the device clock back
/// would stretch a 7-day trial forever (MONETIZATION_v1.0 §10, "rolling the
/// device clock back does not extend the trial"). So we keep a high-water mark
/// of the latest time ever observed and never read earlier than it.
///
/// Two rules, in this order:
///   1. [now] returns `max(deviceNow, highWater)` — a clock rolled BACKWARD is
///      ignored, and the mark advances as real time passes.
///   2. [syncFromServer] *overwrites* the mark with a time Google vouched for
///      (the ID token's issue time). Overwrite, not max: a device clock that
///      was briefly set years into the future would otherwise poison the mark
///      permanently and expire a paying driver's trial early. One online check
///      heals it.
///
/// Prefs failures are soft — off-device (tests) the channel isn't registered,
/// so this degrades to plain `DateTime.now()`, matching SettingsController.
class FoxClock {
  const FoxClock._();

  static const _key = 'foxyco.clock.highwater.v1';

  /// Now, monotone across clock rollbacks. UTC so a timezone change is not
  /// mistaken for time travel.
  static Future<DateTime> now() async {
    final device = DateTime.now().toUtc();
    try {
      final prefs = await SharedPreferences.getInstance();
      final mark = prefs.getInt(_key) ?? 0;
      final ms = device.millisecondsSinceEpoch;
      if (ms > mark) {
        await prefs.setInt(_key, ms);
        return device;
      }
      return DateTime.fromMillisecondsSinceEpoch(mark, isUtc: true);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo clock read skipped: $e');
      return device;
    }
  }

  /// Trust Google over the device: called with the ID token's issue time after
  /// a successful refresh. Resets the high-water mark outright.
  static Future<void> syncFromServer(DateTime serverNow) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, serverNow.toUtc().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo clock sync skipped: $e');
    }
  }
}
