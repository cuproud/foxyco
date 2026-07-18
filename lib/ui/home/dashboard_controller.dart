import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/accessibility/accessibility_watcher.dart';
import '../../services/fox_log.dart';
import '../overlay/overlay_controller.dart';
import 'dashboard_state.dart';

/// Watch/permission state holder. Tally, last offer and watched platforms are
/// derived live from the offer log and settings — no mock data here.
class DashboardController extends Notifier<DashboardState> {
  StreamSubscription<bool>? _statusSub;

  @override
  DashboardState build() {
    // Resilience: the OS pushes accessibility on/off changes (user revoked it
    // in system settings mid-shift, or Android killed the service). Without
    // this the dashboard only notices on the next app resume — the bubble sat
    // there "watching" while FoxyCo was actually deaf. Off-device the plugin
    // channel is missing; the error lands in onError and we stay silent.
    try {
      _statusSub = ref
          .read(accessibilityWatcherProvider)
          .statusChanges
          .listen((enabled) {
        if (kDebugMode) {
          debugPrint('FoxyCo accessibility service ${enabled ? 'ON' : 'OFF'}');
        }
        refreshPermissions();
      }, onError: (Object e) {
        if (kDebugMode) debugPrint('FoxyCo statusChanges unavailable: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo statusChanges skipped: $e');
    }
    ref.onDispose(() => _statusSub?.cancel());

    return const DashboardState(
      status: WatchStatus.watching,
      permissions: PermissionStatus(
        overlayGranted: true,
        accessibilityGranted: true,
      ),
    );
  }

  /// Toggle watching ↔ paused (Home "Pause"/"Resume", bubble long-press later).
  /// No-op while blocked — you can't pause something that isn't running.
  void togglePause() {
    if (state.status == WatchStatus.blocked) return;
    final next = state.status == WatchStatus.paused
        ? WatchStatus.watching
        : WatchStatus.paused;
    state = _with(status: next);
    ref.read(foxLogProvider).log('status', 'watch → ${next.name}');
    if (kDebugMode) debugPrint('FoxyCo watch status → ${next.name}');
  }

  /// Bubble was dropped on the ✕ target (HANDOFF 10): explicit pause.
  /// No-op while paused/blocked.
  void stopWatching() {
    if (state.status != WatchStatus.watching) return;
    state = _with(status: WatchStatus.paused);
    ref.read(foxLogProvider).log('status', 'watch → paused (bubble dropped)');
    if (kDebugMode) debugPrint('FoxyCo watch status → paused (bubble dropped)');
  }

  /// Read real OS permission state (overlay + accessibility) and recompute
  /// [WatchStatus]. Called at app startup and after returning from a settings
  /// trip. Accessibility is the hard gate — without it FoxyCo can't read
  /// offers, so a missing grant forces [WatchStatus.blocked]. If both present
  /// resume watching unless the driver explicitly paused.
  ///
  /// Off-device (widget tests) the plugin channels aren't registered and
  /// throw; we swallow and keep the current (default) state so tests that
  /// pump the screen bare still render "watching".
  Future<void> refreshPermissions() async {
    try {
      final overlay = await ref
          .read(overlayServiceProvider)
          .isPermissionGranted();
      final access = await ref
          .read(accessibilityWatcherProvider)
          .isEnabled();

      final permissions = PermissionStatus(
        overlayGranted: overlay,
        accessibilityGranted: access,
      );
      final WatchStatus status;
      if (!permissions.allGranted) {
        status = WatchStatus.blocked;
      } else if (state.status == WatchStatus.paused) {
        status = WatchStatus.paused; // keep an explicit pause
      } else {
        status = WatchStatus.watching;
      }
      state = _with(status: status, permissions: permissions);
      ref.read(foxLogProvider).log('status', 'watch → ${status.name}');
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo refreshPermissions skipped: $e');
    }
  }

  /// Request whichever permission is still missing, in order: overlay first
  /// (a system toggle), then accessibility (opens the Accessibility settings
  /// page after our disclosure). Each request routes through the plugin and
  /// resolves once the user returns; [refreshPermissions] on resume also keeps
  /// the card honest if they grant it out of band.
  Future<void> requestMissingPermissions() async {
    try {
      if (!state.permissions.overlayGranted) {
        await ref.read(overlayServiceProvider).requestPermission();
      }
      if (!state.permissions.accessibilityGranted) {
        await ref.read(accessibilityWatcherProvider).requestPermission();
      }
      await refreshPermissions();
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo requestMissingPermissions skipped: $e');
    }
  }

  DashboardState _with({
    WatchStatus? status,
    PermissionStatus? permissions,
  }) => DashboardState(
    status: status ?? state.status,
    permissions: permissions ?? state.permissions,
  );
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
