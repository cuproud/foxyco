import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../domain/overlay_action.dart';
import '../domain/overlay_control.dart';
import '../domain/overlay_payload.dart';
import '../domain/bubble_style.dart';

/// Thin wrapper over `flutter_overlay_window` (docs/OVERLAY §plugin).
///
/// Everything plugin-specific lives here so the rest of the app talks in
/// [OverlayPayload]/[OverlayAction]s, and `domain/` stays plugin-free. The
/// overlay UI runs in a *separate isolate* (see `overlay_entry.dart`) — this
/// service runs on the MAIN isolate: it asks permission, shows/hides the
/// window, pushes messages across with `shareData`, and surfaces the bubble's
/// gestures back as an [actionStream].
class OverlayService {
  Future<void> _commands = Future<void>.value();

  /// Native window starts, payloads, resizes and clears must keep invocation
  /// order. Previously only dashboard status changes were serialized, so a
  /// slow first show could land after a clear and resurrect the pill/window.
  Future<T> _enqueue<T>(Future<T> Function() command) {
    final result = _commands.then((_) => command());
    _commands = result.then<void>((_) {}).catchError((_) {});
    return result;
  }

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
      .map((d) => OverlayAction.fromMap(d as Map<dynamic, dynamic>))
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
  Future<void> startWatching({
    bool paused = false,
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) =>
      _enqueue(() => _startWatching(paused: paused, bubbleStyle: bubbleStyle));

  Future<void> _startWatching({
    bool paused = false,
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {
    final wasActive = await FlutterOverlayWindow.isActive();
    if (!wasActive) {
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
      // closeOverlay only removes the WINDOW — the overlay isolate (and its
      // widget state, incl. a shown pill) survives to the next session. A
      // fresh window is bubble-sized, so a stale `_payload` from before the
      // teardown renders as pill text clipped into the 72 dp box (device
      // 2026-07-18: offline demo → go live → garbled bubble). Reset it the
      // moment the window is (re)created. Wait for the overlay isolate's first
      // frame so this one reset is ordered before every later offer.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await FlutterOverlayWindow.shareData(OverlayControl.clearPill());
    }
    await FlutterOverlayWindow.shareData(
      OverlayControl.bubbleStyle(bubbleStyle),
    );
    await FlutterOverlayWindow.shareData(OverlayControl.paused(paused));
  }

  /// Show an offer: ensure the window is up, then push the pill payload into the
  /// overlay isolate. `shareData` reaches the overlay's `overlayListener`.
  ///
  /// The overlay runs in a fresh isolate whose listener only attaches after its
  /// first frame. [startWatching] waits for that listener when it creates a
  /// window, so one ordered payload is enough.
  Future<void> showOffer(
    OverlayPayload payload, {
    BubbleStyle bubbleStyle = BubbleStyle.coolFox,
  }) async {
    await _enqueue(() async {
      await _startWatching(bubbleStyle: bubbleStyle);
      await FlutterOverlayWindow.shareData(payload.toMap());
    });
  }

  /// Update an already-active overlay to a new offer without re-showing.
  Future<void> update(OverlayPayload payload) =>
      _enqueue(() => FlutterOverlayWindow.shareData(payload.toMap()));

  /// Tell the overlay whether we're watching or paused (dims the bubble).
  Future<void> setPaused(bool paused) => _enqueue(
    () => FlutterOverlayWindow.shareData(OverlayControl.paused(paused)),
  );

  Future<void> setBubbleStyle(BubbleStyle style) => _enqueue(
    () => FlutterOverlayWindow.shareData(OverlayControl.bubbleStyle(style)),
  );

  /// Drop the current pill without tearing the overlay down. One ordered clear
  /// only: a delayed duplicate can arrive after the next offer and erase it.
  Future<void> clearPill() => _enqueue(
    () => FlutterOverlayWindow.shareData(OverlayControl.clearPill()),
  );

  /// Tear the overlay window down entirely (stop watching). The isolate (and
  /// its widget state) outlives the window, so drop any shown pill first —
  /// second line of defense alongside [startWatching]'s reset for the same
  /// stale-pill-in-bubble-window bug.
  Future<void> hide() => _enqueue(_hide);

  Future<void> _hide() async {
    // The vendored plugin historically never completed closeOverlay's method
    // result when no service was running. Besides being unnecessary, calling it
    // in that state could permanently block the serialized lifecycle queue at
    // app startup, so the later watching transition never raised the bubble.
    if (!await FlutterOverlayWindow.isActive()) return;
    await FlutterOverlayWindow.shareData(OverlayControl.clearPill());
    await FlutterOverlayWindow.closeOverlay();
  }
}
