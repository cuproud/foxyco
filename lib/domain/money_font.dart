/// Typeface for the big money numbers ($ amounts) app-wide. Driver-picked in
/// Settings → Appearance; Inter is the readable default (Fraunces looked good,
/// but read poorly — device feedback 2026-07-21).
enum MoneyFont {
  inter('Inter', 'Inter'),
  fraunces('Fraunces', 'Fraunces'),
  spaceGrotesk('Space Grotesk', 'Space Grotesk');

  const MoneyFont(this.label, this.family);

  /// Picker display name.
  final String label;

  /// Registered pubspec font family.
  final String family;

  /// Null-safe persisted-name lookup; unknown → [inter].
  static MoneyFont fromName(String? name) =>
      values.where((f) => f.name == name).firstOrNull ?? MoneyFont.inter;
}
