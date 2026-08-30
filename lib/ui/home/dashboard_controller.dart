import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/session_summary.dart';
import '../../services/accessibility/accessibility_watcher.dart';
import '../../services/fox_log.dart';
import '../../services/offer_log.dart';
import '../../services/ocr/ocr_capture.dart';
import '../../services/session_log.dart';
import '../overlay/overlay_controller.dart';
import '../settings/settings_controller.dart';
import 'dashboard_state.dart';

/// Watch/permission state holder. Tally, last offer and watched platforms are
/// derived live from the offer log and settings — no mock data here.
class DashboardController extends Notifier<DashboardState> {
  static const _sessionAnchorKey = 'foxyco.active_session_started_at.v1';
  StreamSubscription<bool>? _statusSub;
  Future<void>? _permissionRefresh;
  bool _permissionRefreshAgain = false;
  bool _starting = false;

  /// When the current live session started; null while stopped. Read by the
  /// shift-recap sheet at stop time. Survives pause (pause ≠ end of shift).
  DateTime? liveSince;

  @override
  DashboardState build() {
    final ocr = ref.read(ocrCaptureProvider);
    // Resilience: the OS pushes accessibility on/off changes (user revoked it
    // in system settings mid-shift, or Android killed the service). Without
    // this the dashboard only notices on the next app resume — the bubble sat
    // there "watching" while FoxyCo was actually deaf. Off-device the plugin
    // channel is missing; the error lands in onError and we stay silent.
    try {
      _statusSub = ref
          .read(accessibilityWatcherProvider)
          .statusChanges
          .listen(
            (enabled) {
              if (kDebugMode) {
                debugPrint(
                  'FoxyCo accessibility service ${enabled ? 'ON' : 'OFF'}',
                );
              }
              refreshPermissions();
            },
            onError: (Object e) {
              if (kDebugMode) {
                debugPrint('FoxyCo statusChanges unavailable: $e');
              }
            },
          );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo statusChanges skipped: $e');
    }
    ref.onDispose(() {
      _statusSub?.cancel();
      unawaited(ocr.stop());
    });
    unawaited(_restoreSessionAnchor());

    return const DashboardState(
      status: WatchStatus.blocked,
      permissions: PermissionStatus(
        overlayGranted: false,
        accessibilityGranted: false,
      ),
    );
  }

  /// Start Monitoring (spec M5 §4): opens the parse gate and summons the
  /// bubble (overlay controller listens on status). Only a stopped session can
  /// start; duplicate starts cannot initialize OCR twice.
  Future<void> startMonitoring() async {
    if (state.status != WatchStatus.stopped || _starting) return;
    _starting = true;
    try {
      final settings = ref.read(settingsProvider);
      if (settings.ocrEnabled) {
        final started = await ref.read(ocrCaptureProvider).start();
        if (!ref.mounted) return;
        ref
            .read(foxLogProvider)
            .log(
              'ocr',
              started
                  ? 'capture ready'
                  : 'capture unavailable — using Accessibility',
            );
      }
      if (!ref.mounted || state.status == WatchStatus.blocked) return;
      liveSince = DateTime.now();
      unawaited(_saveSessionAnchor(liveSince!));
      state = _with(status: WatchStatus.watching);
      ref.read(foxLogProvider).log('status', 'watch → watching (started)');
      if (kDebugMode) debugPrint('FoxyCo watch status → watching (started)');
    } finally {
      _starting = false;
    }
  }

  /// Full stop: overlay torn down, parse gate closed. Works from watching
  /// AND paused (pause is a layer on top of running). Returns when this
  /// session went live (null if it never did) — the shift recap reads it.
  DateTime? stopMonitoring() {
    if (state.status == WatchStatus.blocked ||
        state.status == WatchStatus.stopped) {
      return null;
    }
    final since = liveSince;
    unawaited(ref.read(ocrCaptureProvider).stop());
    liveSince = null;
    unawaited(_clearSessionAnchor());
    _recordSession(since);
    state = _with(status: WatchStatus.stopped);
    ref.read(foxLogProvider).log('status', 'watch → stopped');
    if (kDebugMode) debugPrint('FoxyCo watch status → stopped');
    return since;
  }

  /// Roll the just-ended session into the session log (Home "Last session"
  /// card). Both stop paths — slide-stop and bubble-drop — funnel through
  /// here, so the card never misses a session the recap sheet would skip.
  ///
  /// A mis-slide is dropped rather than recorded ([SessionSummary.isTrivial]):
  /// going live and stopping within the minute, with nothing seen, buried a
  /// real 3h shift under an empty "0m" card on device 2026-07-24.
  void _recordSession(DateTime? since) {
    if (since == null) return;
    final session = SessionSummary.from(
      startedAt: since,
      endedAt: DateTime.now(),
      offers: ref.read(offerLogProvider),
    );
    if (session.isTrivial) {
      ref.read(foxLogProvider).log('status', 'session skipped (trivial)');
      return;
    }
    ref.read(sessionLogProvider.notifier).record(session);
  }

  /// Toggle watching ↔ paused (bubble long-press; Start/Stop is the outer
  /// gate). No-op while blocked or stopped — you can't pause something that
  /// isn't running.
  void togglePause() {
    if (state.status == WatchStatus.blocked ||
        state.status == WatchStatus.stopped) {
      return;
    }
    final next = state.status == WatchStatus.paused
        ? WatchStatus.watching
        : WatchStatus.paused;
    if (next == WatchStatus.paused) {
      unawaited(ref.read(ocrCaptureProvider).stop());
    }
    state = _with(status: next);
    ref.read(foxLogProvider).log('status', 'watch → ${next.name}');
    if (kDebugMode) debugPrint('FoxyCo watch status → ${next.name}');
  }

  /// Bubble was dropped on the ✕ target: full stop (the native side already
  /// closed the overlay window, so "stopped" keeps app and overlay in sync).
  void stopWatching() {
    if (state.status != WatchStatus.watching &&
        state.status != WatchStatus.paused) {
      return;
    }
    final since = liveSince;
    unawaited(ref.read(ocrCaptureProvider).stop());
    liveSince = null; // session over — no recap for a bubble-drop stop
    unawaited(_clearSessionAnchor());
    _recordSession(since); // …but it still counts as a session
    state = _with(status: WatchStatus.stopped);
    ref.read(foxLogProvider).log('status', 'watch → stopped (bubble dropped)');
    if (kDebugMode) {
      debugPrint('FoxyCo watch status → stopped (bubble dropped)');
    }
  }

  /// Read real OS permission state (overlay + accessibility) and recompute
  /// [WatchStatus]. Called at app startup and after returning from a settings
  /// trip. Accessibility is the hard gate — without it FoxyCo can't read
  /// offers, so a missing grant forces [WatchStatus.blocked]. If both present
  /// resume watching unless the driver explicitly paused.
  ///
  /// Off-device (widget tests) the plugin channels aren't registered and
  /// throw; we swallow and keep the current fail-closed state.
  Future<void> refreshPermissions() {
    // Startup, app-resume and the accessibility status observer can all request
    // this check in the same frame. Share one platform-channel round trip so a
    // single permission transition does not produce duplicate state writes,
    // log lines and overlay `isActive` calls (device log 2026-07-30).
    final active = _permissionRefresh;
    if (active != null) {
      _permissionRefreshAgain = true;
      return active;
    }

    late final Future<void> refresh;
    refresh = _runPermissionRefreshes().whenComplete(() {
      if (!identical(_permissionRefresh, refresh)) return;
      _permissionRefresh = null;
      // Close the tiny completion window: a status event can arrive after the
      // loop's final condition but before this cleanup callback runs.
      if (_permissionRefreshAgain && ref.mounted) {
        unawaited(refreshPermissions());
      }
    });
    _permissionRefresh = refresh;
    return refresh;
  }

  Future<void> _runPermissionRefreshes() async {
    do {
      _permissionRefreshAgain = false;
      await _refreshPermissions();
    } while (_permissionRefreshAgain && ref.mounted);
  }

  Future<void> _refreshPermissions() async {
    try {
      final overlay = await ref
          .read(overlayServiceProvider)
          .isPermissionGranted();
      final access = await ref.read(accessibilityWatcherProvider).isEnabled();

      final permissions = PermissionStatus(
        overlayGranted: overlay,
        accessibilityGranted: access,
      );
      final WatchStatus status;
      var recoverOverlay = false;
      if (!permissions.allGranted) {
        status = WatchStatus.blocked;
      } else if (state.status == WatchStatus.watching) {
        // "Watching" is only real while the bubble window is actually up.
        // Swipe-away / OOM kills the overlay service while this in-memory
        // state lives on, and the dashboard showed a stale "online" on
        // reopen (device 2026-07-19). Paused is exempt: its overlay is torn
        // down BY DESIGN (see OverlayController._applyStatus).
        final overlayUp = await ref.read(overlayServiceProvider).isActive();
        status = WatchStatus.watching;
        recoverOverlay = !overlayUp;
      } else if (state.status == WatchStatus.paused) {
        status = state.status; // explicit pause survives a refresh
      } else if (liveSince != null) {
        // Process restart: a surviving overlay means the same shift is still
        // live. Otherwise close the recovered shift instead of losing it.
        final overlayUp = await ref.read(overlayServiceProvider).isActive();
        status = overlayUp ? WatchStatus.watching : WatchStatus.stopped;
      } else {
        status = WatchStatus.stopped; // granted but user hasn't started
      }
      final old = state;
      final permissionsChanged =
          old.permissions.overlayGranted != permissions.overlayGranted ||
          old.permissions.accessibilityGranted !=
              permissions.accessibilityGranted;
      final statusChanged = old.status != status;
      final endsRecoveredSession =
          liveSince != null &&
          (status == WatchStatus.blocked || status == WatchStatus.stopped);
      if (!statusChanged &&
          !permissionsChanged &&
          !endsRecoveredSession &&
          !recoverOverlay) {
        return;
      }

      if (endsRecoveredSession) {
        final since = liveSince;
        unawaited(ref.read(ocrCaptureProvider).stop());
        liveSince = null;
        unawaited(_clearSessionAnchor());
        _recordSession(since);
      }
      state = _with(status: status, permissions: permissions);
      if (recoverOverlay) {
        ref
            .read(foxLogProvider)
            .log(
              'error',
              'overlay reported inactive while watching — recovering window',
            );
        unawaited(
          ref
              .read(overlayServiceProvider)
              .startWatching(
                bubbleStyle: ref.read(settingsProvider).bubbleStyle,
              )
              .catchError(
                (Object error) => ref
                    .read(foxLogProvider)
                    .log('error', 'overlay recovery failed: $error'),
              ),
        );
      }
      if (statusChanged) {
        ref.read(foxLogProvider).log('status', 'watch → ${status.name}');
      }
      if (permissionsChanged) {
        ref
            .read(foxLogProvider)
            .log(
              'permission',
              'overlay=${permissions.overlayGranted} '
                  'accessibility=${permissions.accessibilityGranted}',
            );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo refreshPermissions skipped: $e');
    }
  }

  Future<void> _restoreSessionAnchor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(_sessionAnchorKey);
      if (millis == null || liveSince != null) return;
      final saved = DateTime.fromMillisecondsSinceEpoch(millis);
      final age = DateTime.now().difference(saved);
      if (age.isNegative || age > const Duration(hours: 24)) {
        await prefs.remove(_sessionAnchorKey);
        return;
      }
      liveSince = saved;
      if (ref.mounted) await refreshPermissions();
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo session restore skipped: $e');
    }
  }

  Future<void> _saveSessionAnchor(DateTime value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionAnchorKey, value.millisecondsSinceEpoch);
    } catch (_) {
      // Monitoring must remain usable when persistence is unavailable.
    }
  }

  Future<void> _clearSessionAnchor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionAnchorKey);
    } catch (_) {
      // Best effort; stale anchors are age-limited during restore.
    }
  }

  /// Request whichever permission is still missing, in order: overlay first
  /// (a system toggle), then accessibility (opens the Accessibility settings
  /// page after our disclosure). Each request routes through the plugin and
  /// resolves once the user returns; [refreshPermissions] on resume also keeps
  /// the card honest if they grant it out of band.
  Future<void> requestMissingPermissions({
    required Future<bool> Function() confirmAccessibility,
  }) async {
    try {
      if (!state.permissions.overlayGranted) {
        await ref.read(overlayServiceProvider).requestPermission();
      }
      if (!state.permissions.accessibilityGranted) {
        if (!await confirmAccessibility()) return;
        await ref.read(accessibilityWatcherProvider).requestPermission();
      }
      await refreshPermissions();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FoxyCo requestMissingPermissions skipped: $e');
      }
    }
  }

  DashboardState _with({WatchStatus? status, PermissionStatus? permissions}) =>
      DashboardState(
        status: status ?? state.status,
        permissions: permissions ?? state.permissions,
      );
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
