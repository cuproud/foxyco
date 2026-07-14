/// Control messages the main isolate sends TO the overlay that aren't offers —
/// e.g. "you're paused now" or "clear the pill". Pure Dart primitive maps,
/// tagged `kind: 'control'` so the overlay can route them apart from offers
/// ([OverlayPayload]) on the shared `shareData` channel.
///
/// Kept as static builders rather than an enum because each carries different
/// data (paused carries a bool); the overlay reads them by field.
class OverlayControl {
  const OverlayControl._();

  /// Tell the overlay whether FoxyCo is watching — the bubble dims when paused.
  static Map<String, dynamic> paused(bool value) => {
    'kind': 'control',
    'paused': value,
  };

  /// Tell the overlay to drop the current pill (e.g. offer dismissed on main).
  static Map<String, dynamic> clearPill() => {
    'kind': 'control',
    'clearPill': true,
  };

  static bool isControl(Map<dynamic, dynamic> map) => map['kind'] == 'control';
}
