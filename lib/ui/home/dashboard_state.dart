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

  bool get isEmpty => good == 0 && ok == 0 && bad == 0;
}

/// Watch/permission state the Home dashboard renders. Tally, last offer and
/// watched platforms come straight from [offerLogProvider]/[settingsProvider].
class DashboardState {
  final WatchStatus status;
  final PermissionStatus permissions;

  const DashboardState({
    required this.status,
    required this.permissions,
  });
}
