/// Which palette the app paints in. Driver-picked in Settings → Appearance;
/// dark is the default the app shipped with, light was added for daylight
/// (device 2026-07-24: the dark theme is unreadable outdoors in the afternoon).
///
/// Pure Dart, like the rest of `domain/` — the UI maps this to Flutter's
/// `ThemeMode`.
enum AppSkin {
  dark('Dark', 'Night shifts, garage lighting'),
  light('Light', 'Daylight, windscreen glare'),
  system('Auto', 'Follows your phone');

  const AppSkin(this.label, this.blurb);

  /// Picker display name.
  final String label;

  /// One-line description under the label.
  final String blurb;

  /// Null-safe persisted-name lookup; unknown → [dark].
  static AppSkin fromName(String? name) =>
      values.where((s) => s.name == name).firstOrNull ?? AppSkin.dark;
}
