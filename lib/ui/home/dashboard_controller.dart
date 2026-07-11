import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';
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
      activePlatforms: const [GigPlatform.uber, GigPlatform.hopp],
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
  void togglePause() {
    final next = state.status == WatchStatus.paused
        ? WatchStatus.watching
        : WatchStatus.paused;
    state = DashboardState(
      status: next,
      permissions: state.permissions,
      activePlatforms: state.activePlatforms,
      today: state.today,
      lastOffer: state.lastOffer,
    );
    if (kDebugMode) {
      debugPrint('FoxyCo watch status → $next');
    }
  }
}

final dashboardProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
