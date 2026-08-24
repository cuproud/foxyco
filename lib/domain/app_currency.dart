/// Currency label attached to fares reported by the watched gig app.
/// FoxyCo never performs foreign-exchange conversion.
enum AppCurrency {
  usd,
  cad,
  aud,
  nzd,
  mxn,
  brl;

  String get label => switch (this) {
    cad => 'CAD',
    usd => 'USD',
    aud => 'AUD',
    nzd => 'NZD',
    mxn => 'MXN',
    brl => 'BRL',
  };

  String get prefix => switch (this) {
    cad => r'CA$',
    usd => r'US$',
    aud => r'A$',
    nzd => r'NZ$',
    mxn => r'MX$',
    brl => r'R$',
  };

  /// Compact money mark for dense summary cards where the selected currency
  /// is already established in Settings. Full offer details keep [prefix].
  String get symbol => switch (this) {
    brl => r'R$',
    _ => r'$',
  };

  static AppCurrency fromCountryCode(String? code) =>
      switch (code?.toUpperCase()) {
        'US' => usd,
        'AU' => aud,
        'NZ' => nzd,
        'MX' => mxn,
        'BR' => brl,
        _ => cad,
      };

  static AppCurrency fromName(String? name) =>
      values.firstWhere((currency) => currency.name == name, orElse: () => cad);
}
