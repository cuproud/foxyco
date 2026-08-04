/// Currency label attached to fares reported by the watched gig app.
/// FoxyCo never performs foreign-exchange conversion.
enum AppCurrency {
  cad,
  usd;

  String get label => switch (this) {
    cad => 'CAD',
    usd => 'USD',
  };

  String get prefix => switch (this) {
    cad => r'CA$',
    usd => r'US$',
  };

  static AppCurrency fromName(String? name) =>
      values.firstWhere((currency) => currency.name == name, orElse: () => cad);
}
