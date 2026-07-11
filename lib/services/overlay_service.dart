import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../domain/overlay_action.dart';
import '../domain/overlay_control.dart';
import '../domain/overlay_payload.dart';

/// Thin wrapper over `flutter_overlay_window` (docs/OVERLAY §plugin).
///
/// Everything plugin-specific lives here so the rest of the app talks in
/// [OverlayPayload]/[OverlayAction]s, and `domain/` stays plugin-free. The
/// overlay UI runs in a *separate isolate* (see `overlay_entry.dart`) — this
/// service runs on the MAIN isolate: it asks permission, shows/hides the
/// window, pushes messages across with `shareData`, and surfaces the bubble's
/// gestures back as an [actionStream].
class OverlayService {
  const OverlayService();

  /// Is "Display over other apps" granted?
  Future<bool> isPermissionGranted() =>
      FlutterOverlayWindow.isPermissionGranted();

  /// Opens the system settings page; resolves true once the user grants it.
  Future<bool> requestPermission() async =>
      await FlutterOverlayWindow.requestPermission() ?? false;

  Future<bool> isActive() => FlutterOverlayWindow.isActive();

  /// Actions the bubble sends back (tap → openApp, long-press → togglePause).
  /// Decoded from the raw overlay channel; non-action messages are filtered out.
  Stream<OverlayAction> get actionStream => FlutterOverlayWindow.overlayListener
      .where((d) => d is Map)
      .map((d) => OverlayAction.fromMap(d as Map))
      .where((a) => a != null)
      .cast<OverlayAction>();

  /// Bring the overlay up in its resting state (bubble only, no pill). Called
  /// when FoxyCo starts watching. Full-cover so the bubble can pin to a screen
  /// edge and a pill can later drop in at the top; [OverlayFlag.defaultFlag]
  /// lets touches through everywhere except our actual widgets.
  Future<void> startWatching({bool paused = false}) async {
    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.fullCover,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag, // pass-through except on our widgets
        enableDrag: true,
        positionGravity: PositionGravity.auto, // snap to an edge after a drag
        overlayTitle: 'FoxyCo',
        overlayContent: 'Watching for offers',
      );
    }
    await setPaused(paused);
  }

  /// Show an offer: ensure the window is up, then push the pill payload into the
  /// overlay isolate. `shareData` reaches the overlay's `overlayListener`.
  Future<void> showOffer(OverlayPayload payload) async {
    await startWatching();
    await FlutterOverlayWindow.shareData(payload.toMap());
  }

  /// Update an already-active overlay to a new offer without re-showing.
  Future<void> update(OverlayPayload payload) =>
      FlutterOverlayWindow.shareData(payload.toMap());

  /// Tell the overlay whether we're watching or paused (dims the bubble).
  Future<void> setPaused(bool paused) =>
      FlutterOverlayWindow.shareData(OverlayControl.paused(paused));

  /// Drop the current pill without tearing the overlay down.
  Future<void> clearPill() =>
      FlutterOverlayWindow.shareData(OverlayControl.clearPill());

  /// Tear the overlay window down entirely (stop watching).
  Future<void> hide() => FlutterOverlayWindow.closeOverlay();
}
