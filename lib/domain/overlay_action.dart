/// Messages the overlay isolate sends BACK to the main isolate (the reverse of
/// [OverlayPayload]). Pure Dart, primitive wire format — same discipline as the
/// forward channel so both isolates and tests can share it.
///
/// The bubble's gestures can't touch Riverpod directly (separate isolate), so a
/// tap/long-press becomes one of these, is `shareData`'d across, and the main
/// isolate acts on it (pause the engine, bring the app forward).
enum OverlayAction {
  /// Long-press the bubble → flip watching ↔ paused.
  togglePause,

  /// Tap the bubble → bring FoxyCo to the foreground.
  openApp,

  /// Drag the bubble to the bottom drop zone → stop watching entirely. The
  /// native side tears the overlay window down; this message tells the main
  /// isolate to flip the dashboard to "not watching" so the two never desync
  /// (HANDOFF req 10 — before, the window closed but the app still showed
  /// "active"). Distinct from [togglePause]: this is a full stop, not a pause.
  stopWatching;

  /// Wrap as a primitive map tagged so the main isolate can tell an action
  /// message apart from other `shareData` traffic. Enum crosses as its stable
  /// `name`, never the index.
  Map<String, dynamic> toMap() => {'kind': 'action', 'action': name};

  /// Decode an action from a `shareData` map, or null if it isn't one (fails
  /// safe — an unrelated/garbage map is simply ignored, never throws).
  static OverlayAction? fromMap(Map<dynamic, dynamic> map) {
    if (map['kind'] != 'action') return null;
    for (final a in OverlayAction.values) {
      if (a.name == map['action']) return a;
    }
    return null;
  }
}
