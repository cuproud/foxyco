import '../../domain/offer_summary.dart';
import '../../domain/platform.dart';
import '../../domain/verdict.dart';

/// Whether FoxyCo is actively watching, paused, or blocked on a permission.
enum WatchStatus {
  /// Live and reading offers.
  watching,

  /// Driver paused it (bubble long-press / Home pause).
  paused,

  /// A required permission is missing — can't watch until fixed.
  blocked,
}

/// The two OS permissions FoxyCo needs (overlay + accessibility).
class PermissionStatus {
  final bool overlayGranted;
  final bool accessibilityGranted;

  const PermissionStatus({
    required this.overlayGranted,
    required this.accessibilityGranted,
  });

  bool get allGranted => overlayGranted && accessibilityGranted;
}

/// Today's verdict counts (count only — no graphs in MVP).
class Tally {
  final int good;
  final int ok;
  final int bad;

  const Tally({this.good = 0, this.ok = 0, this.bad = 0});

  int countFor(Verdict v) => switch (v) {
    Verdict.good => good,
    Verdict.ok => ok,
    Verdict.bad => bad,
    Verdict.unknown => 0,
  };

  bool get isEmpty => good == 0 && ok == 0 && bad == 0;
}

/// Everything the Home dashboard renders.
class DashboardState {
  final WatchStatus status;
  final PermissionStatus permissions;
  final List<GigPlatform> activePlatforms;
  final Tally today;
  final OfferSummary? lastOffer;

  const DashboardState({
    required this.status,
    required this.permissions,
    required this.activePlatforms,
    required this.today,
    required this.lastOffer,
  });
}
