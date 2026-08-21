enum AppTextSize {
  small('Small', 0.92),
  medium('Medium', 1),
  large('Large', 1.12);

  const AppTextSize(this.label, this.factor);

  final String label;
  final double factor;

  static AppTextSize fromName(String? name) =>
      values.firstWhere((value) => value.name == name, orElse: () => medium);
}
