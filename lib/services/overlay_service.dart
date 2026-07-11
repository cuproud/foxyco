import 'dart:ui' show PlatformDispatcher;

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

  /// Overlay window size in **logical px (dp)**. A COMPACT box (not full-screen)
  /// is what makes it draggable to BOTH edges: a `matchParent`/`fullCover` window
  /// has no room to move horizontally, so `positionGravity` could only ever pin
  /// it right. Sized to hold the widest pill; the bubble sits centered inside.
  static const double _overlayWidthDp = 300;
  static const double _overlayHeightDp = 120;

  /// The plugin's INITIAL `showOverlay` size is raw PHYSICAL pixels (its native
  /// code skips dp→px conversion on first show — only resize/move convert). So a
  /// dp value passed straight through comes out ~3× too small on a 3× screen and
  /// clips the pill/bubble to nothing. Convert dp→px ourselves using the screen
  /// density. No BuildContext here, so read it off the platform view directly.
  static int _dpToPx(double dp) {
    final views = PlatformDispatcher.instance.views;
    final dpr = views.isNotEmpty ? views.first.devicePixelRatio : 3.0;
    return (dp * dpr).round();
  }

  /// Bring the overlay up in its resting state (bubble). Called when FoxyCo
  /// starts watching. A small draggable box: [OverlayFlag.defaultFlag] lets
  /// touches through the transparent area, `enableDrag` + `positionGravity.auto`
  /// let the user fling it to either side of the screen.
  Future<void> startWatching({bool paused = false}) async {
    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        height: _dpToPx(_overlayHeightDp),
        width: _dpToPx(_overlayWidthDp),
        alignment: OverlayAlignment.topRight,
        flag: OverlayFlag.defaultFlag, // pass-through except on our widgets
        enableDrag: true,
        positionGravity: PositionGravity.auto, // snap to nearest edge, either side
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
