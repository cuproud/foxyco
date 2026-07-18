/// Vehicle body style — picks the hero-card silhouette (spec M5 §3).
enum VehicleType { sedan, suv, hatchback, pickup, van, motorbike }

/// The driver's profile (spec M5 §3). Pure Dart — color is an ARGB int so
/// `domain/` stays Flutter-free; UI wraps it in `Color(...)`.
///
/// All fields optional; "complete enough for the hero card" == non-empty name.
/// [toJson]/[fromJson] are the whole storage format (one SharedPreferences
/// string, key `foxyco.profile.v1`) — same discipline as [FoxSettings].
class DriverProfile {
  const DriverProfile({
    this.name = '',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleYear = '',
    this.licensePlate = '',
    this.vehicleColor = 0xFFF5F5F5, // white
    this.vehicleType = VehicleType.sedan,
  });

  final String name;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleYear;
  final String licensePlate;
  final int vehicleColor; // ARGB
  final VehicleType vehicleType;

  static const empty = DriverProfile();

  /// Fixed swatch row (spec): value → display name used in [vehicleLine].
  static const palette = <int, String>{
    0xFFF5F5F5: 'White',
    0xFF212121: 'Black',
    0xFFB0BEC5: 'Silver',
    0xFF757575: 'Gray',
    0xFFC62828: 'Red',
    0xFF1565C0: 'Blue',
    0xFF2E7D32: 'Green',
    0xFFF9A825: 'Gold',
    0xFFEF6C00: 'Orange',
    0xFF5D4037: 'Brown',
  };

  bool get hasName => name.trim().isNotEmpty;

  String get colorName => palette[vehicleColor] ?? '';

  /// "Red 2022 Toyota Camry · ABC-123" — empty parts skipped cleanly. The
  /// color only shows alongside real vehicle info: a default swatch on an
  /// otherwise-empty profile isn't a vehicle.
  String get vehicleLine {
    final vehicle = [vehicleYear, vehicleMake, vehicleModel]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    final desc = vehicle.isEmpty
        ? ''
        : [colorName, vehicle].where((s) => s.isNotEmpty).join(' ');
    final plate = licensePlate.trim();
    if (desc.isEmpty && plate.isEmpty) return '';
    if (plate.isEmpty) return desc;
    if (desc.isEmpty) return plate;
    return '$desc · $plate';
  }

  DriverProfile copyWith({
    String? name,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleYear,
    String? licensePlate,
    int? vehicleColor,
    VehicleType? vehicleType,
  }) =>
      DriverProfile(
        name: name ?? this.name,
        vehicleMake: vehicleMake ?? this.vehicleMake,
        vehicleModel: vehicleModel ?? this.vehicleModel,
        vehicleYear: vehicleYear ?? this.vehicleYear,
        licensePlate: licensePlate ?? this.licensePlate,
        vehicleColor: vehicleColor ?? this.vehicleColor,
        vehicleType: vehicleType ?? this.vehicleType,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'make': vehicleMake,
        'model': vehicleModel,
        'year': vehicleYear,
        'plate': licensePlate,
        'color': vehicleColor,
        'type': vehicleType.name,
      };

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        name: j['name'] is String ? j['name'] as String : '',
        vehicleMake: j['make'] is String ? j['make'] as String : '',
        vehicleModel: j['model'] is String ? j['model'] as String : '',
        vehicleYear: j['year'] is String ? j['year'] as String : '',
        licensePlate: j['plate'] is String ? j['plate'] as String : '',
        vehicleColor: j['color'] is int ? j['color'] as int : 0xFFF5F5F5,
        vehicleType: VehicleType.values
                .where((t) => t.name == j['type'])
                .firstOrNull ??
            VehicleType.sedan,
      );
}
