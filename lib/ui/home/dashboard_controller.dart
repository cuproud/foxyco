import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
import '../../services/accessibility/accessibility_watcher.dart';
import '../overlay/overlay_controller.dart';
import 'dashboard_state.dart';

/// Dashboard state holder.
///
/// MVP note: this is seeded with MOCK data so the UI is buildable and reviewable
/// before the overlay (M2) and parser (M3) exist. Real data will flow in from
/// the offer repository (Drift) and the permission/service layer — this
/// controller keeps the same public shape, only the source changes.
class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return DashboardState(
      status: WatchStatus.watching,
      permissions: const PermissionStatus(
        overlayGranted: true,
        accessibilityGranted: true,
      ),
      activePlatforms: const [
        GigPlatform.uber,
        GigPlatform.hopp,
        GigPlatform.lyft,
      ],
      today: const Tally(good: 12, ok: 7, bad: 4),
      lastOffer: OfferSummary(
        platform: GigPlatform.uber,
        verdict: Verdict.good,
        payout: 12.00,
        totalKm: 8.4,
        // Fixed timestamp keeps builds/tests deterministic; real data uses now().
        seenAt: DateTime(2026, 7, 10, 14, 28),
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
    if (kDebugMode) {
      debugPrint('FoxyCo watch status → $next');
    }
  }

  /// Full stop, initiated by dragging the overlay bubble into the bottom drop
  /// zone (HANDOFF req 10). The native side has already torn the overlay window
  /// down; this only flips dashboard state so the two stay in sync — before,
  /// the window closed but the card still read "Watching". Modeled as a pause
  /// (permissions are intact; the driver simply turned it off) so Resume brings
  /// it straight back. No-op if already paused/blocked.
  void stopWatching() {
    if (state.status != WatchStatus.watching) return;
    state = _with(status: WatchStatus.paused);
    if (kDebugMode) debugPrint('FoxyCo watch status → paused (bubble dropped)');
  }

  /// Read the real OS permission state (overlay + accessibility) and recompute
  /// [WatchStatus]. Called at app startup and after returning from a settings
  /// trip. Accessibility is the hard gate — without it FoxyCo can't read offers,
  /// so a missing grant forces [WatchStatus.blocked]. If both are present we
  /// resume watching unless the driver had explicitly paused.
  ///
  /// Off-device (widget tests) the plugin channels aren't registered and throw;
  /// we swallow that and keep the current (mock/default) state so tests that
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
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo refreshPermissions skipped: $e');
    }
  }

  /// Request whichever permission is still missing, in order: overlay first
  /// (a system toggle), then accessibility (opens the Accessibility settings
  /// page with our disclosure). Each request routes through the plugin, which
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
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo requestMissingPermissions: $e');
    }
    await refreshPermissions();
  }

  /// Rebuild state changing only the given fields (mock tally/last-offer and the
  /// rest carry over). Replaces the hand-rolled full-constructor calls.
  DashboardState _with({
    WatchStatus? status,
    PermissionStatus? permissions,
  }) => DashboardState(
    status: status ?? state.status,
    permissions: permissions ?? state.permissions,
    activePlatforms: state.activePlatforms,
    today: state.today,
    lastOffer: state.lastOffer,
  );
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
