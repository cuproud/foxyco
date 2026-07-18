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

  /// Resting window size in **logical dp** (converted to physical px below).
  /// The window starts BUBBLE-sized — small enough to hug a screen edge and be
  /// dragged/snapped freely. The overlay isolate grows it to fit the pill while
  /// an offer is live and shrinks it back on clear (see overlay_entry.dart's
  /// resizeOverlay calls). A fixed wide window can't do this: it would centre
  /// the bubble mid-screen and be too wide to drag to an edge.
  ///
  /// A COMPACT window is also essential for touch: a full-cover overlay with a
  /// focusable flag traps EVERY touch on the screen, locking the user out.
  static const double _restWidthDp = 72;
  static const double _restHeightDp = 72;

  /// The plugin's INITIAL `showOverlay` size is raw PHYSICAL pixels (its native
  /// code skips dp→px conversion on first show — only resize/move convert). So a
  /// dp value passed straight through comes out ~3× too small on a 3× screen.
  /// Convert dp→px ourselves from the screen density (no BuildContext here).
  /// NOTE: `resizeOverlay` (used later for the pill) DOES convert, so it takes dp.
  static int _dpToPx(double dp) {
    final views = PlatformDispatcher.instance.views;
    final dpr = views.isNotEmpty ? views.first.devicePixelRatio : 3.0;
    return (dp * dpr).round();
  }

  /// Bring the overlay up in its resting state (bubble). Called when FoxyCo
  /// starts watching.
  ///
  /// Compact, draggable window resting on the RIGHT edge, vertically centered
  /// (`centerRight`) — safely on-screen, clear of the status bar / camera cutout
  /// that made a top-anchored window clip off the top. `enableDrag` +
  /// `positionGravity.auto` let the user fling it to either edge.
  Future<void> startWatching({bool paused = false}) async {
    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        height: _dpToPx(_restHeightDp),
        width: _dpToPx(_restWidthDp),
        alignment: OverlayAlignment.centerRight,
        flag: OverlayFlag.defaultFlag, // touch only over our small window
        enableDrag: true,
        positionGravity: PositionGravity.auto, // snap to nearest edge
        overlayTitle: 'FoxyCo',
        overlayContent: 'Watching for offers',
      );
    }
    await setPaused(paused);
  }

  /// Show an offer: ensure the window is up, then push the pill payload into the
  /// overlay isolate. `shareData` reaches the overlay's `overlayListener`.
  ///
  /// The overlay runs in a fresh isolate whose listener only attaches after its
  /// first frame — a `shareData` sent the instant `showOverlay` returns can land
  /// before anyone is listening and get dropped (bubble still shows; pill never
  /// does). So when we just brought the window up, settle briefly then send, and
  /// send once more as a belt-and-braces against the race.
  /// ponytail: a fixed delay, not a handshake — the plugin exposes no readiness
  /// signal. Replace with a real ack if the pill ever flakes.
  Future<void> showOffer(OverlayPayload payload) async {
    final wasActive = await FlutterOverlayWindow.isActive();
    await startWatching();
    if (!wasActive) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    await FlutterOverlayWindow.shareData(payload.toMap());
  }

  /// Update an already-active overlay to a new offer without re-showing.
  Future<void> update(OverlayPayload payload) =>
      FlutterOverlayWindow.shareData(payload.toMap());

  /// Tell the overlay whether we're watching or paused (dims the bubble).
  Future<void> setPaused(bool paused) =>
      FlutterOverlayWindow.shareData(OverlayControl.paused(paused));

  /// Drop the current pill without tearing the overlay down. Sent twice, like
  /// [showOffer]'s belt-and-braces: a single `shareData` can be dropped while
  /// the overlay isolate is waking from idle (plugin characteristic, worse in
  /// debug), which left a stale pill hanging until the safety timer.
  Future<void> clearPill() async {
    await FlutterOverlayWindow.shareData(OverlayControl.clearPill());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await FlutterOverlayWindow.shareData(OverlayControl.clearPill());
  }

  /// Tear the overlay window down entirely (stop watching).
  Future<void> hide() => FlutterOverlayWindow.closeOverlay();
}
