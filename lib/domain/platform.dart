/// Canonical platform metadata known to FoxyCo. Presence here does not imply a
/// production parser; parser capability is owned by [ParserRegistry].
enum GigPlatform {
  uber('uber', 'Uber', 'U', 0xFF111111, 'com.ubercab.driver'),
  hopp('hopp', 'Hopp', 'H', 0xFF2E7D32, 'ee.hopp.driver'),
  lyft('lyft', 'Lyft', 'L', 0xFFFF37A6, 'com.lyft.android.driver'),
  uberEats('uber_eats', 'Uber Eats', 'E', 0xFF111111, 'com.ubercab.driver'),
  doorDash('doordash', 'DoorDash', 'D', 0xFFFF3008, 'com.doordash.driverapp'),
  instacart('instacart', 'Instacart', 'I', 0xFF43A047, 'com.instacart.shopper'),
  skip('skip', 'Skip', 'S', 0xFFFF8000, 'com.delco.courier');

  const GigPlatform(
    this.id,
    this.label,
    this.initial,
    this.colorValue,
    this.packageName,
  );
  final String id;
  final String label;
  final String initial;
  final int colorValue;
  final String packageName;

  bool get isDelivery => this == doorDash || this == instacart || this == skip;
  bool get isBeta => isDelivery;
}
