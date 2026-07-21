import 'driver_profile.dart';

/// Powertrain — drives the fuel badge on cards + art (spec M6 §4.1).
enum FuelType { gas, hybrid, ev }

/// One vehicle in the garage. Pure Dart — color is an ARGB int so `domain/`
/// stays Flutter-free; UI wraps it in `Color(...)`.
class Vehicle {
  const Vehicle({
    required this.id,
    this.make = '',
    this.model = '',
    this.year = '',
    this.plate = '',
    this.colorValue = 0xFFF5F5F5, // white
    this.bodyType = VehicleType.sedan,
    this.fuelType = FuelType.gas,
  });

  final String id;
  final String make;
  final String model;
  final String year;
  final String plate;
  final int colorValue; // ARGB
  final VehicleType bodyType;
  final FuelType fuelType;

  String get colorName => DriverProfile.palette[colorValue] ?? '';

  /// "2022 Toyota Camry" — empty parts skipped cleanly.
  String get title =>
      [year, make, model].where((s) => s.trim().isNotEmpty).join(' ');

  /// "Red 2022 Toyota Camry · ABC-123" — matches [DriverProfile.vehicleLine].
  /// The color only shows alongside real vehicle info.
  String get vehicleLine {
    final vehicle = title;
    final desc = vehicle.isEmpty
        ? ''
        : [colorName, vehicle].where((s) => s.isNotEmpty).join(' ');
    final p = plate.trim();
    if (desc.isEmpty && p.isEmpty) return '';
    if (p.isEmpty) return desc;
    if (desc.isEmpty) return p;
    return '$desc · $p';
  }

  Vehicle copyWith({
    String? make,
    String? model,
    String? year,
    String? plate,
    int? colorValue,
    VehicleType? bodyType,
    FuelType? fuelType,
  }) => Vehicle(
    id: id,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    plate: plate ?? this.plate,
    colorValue: colorValue ?? this.colorValue,
    bodyType: bodyType ?? this.bodyType,
    fuelType: fuelType ?? this.fuelType,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'plate': plate,
    'color': colorValue,
    'body': bodyType.name,
    'fuel': fuelType.name,
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] is String ? j['id'] as String : '',
    make: j['make'] is String ? j['make'] as String : '',
    model: j['model'] is String ? j['model'] as String : '',
    year: j['year'] is String ? j['year'] as String : '',
    plate: j['plate'] is String ? j['plate'] as String : '',
    colorValue: j['color'] is int ? j['color'] as int : 0xFFF5F5F5,
    bodyType:
        VehicleType.values.where((t) => t.name == j['body']).firstOrNull ??
        VehicleType.sedan,
    fuelType:
        FuelType.values.where((t) => t.name == j['fuel']).firstOrNull ??
        FuelType.gas,
  );
}

/// The multi-vehicle garage (spec M6 §4). [toJson]/[fromJson] are the whole
/// storage format (one SharedPreferences string, key `foxyco.garage.v1`) —
/// same discipline as [DriverProfile].
class Garage {
  const Garage({this.vehicles = const [], this.activeId = ''});

  final List<Vehicle> vehicles;
  final String activeId;

  static const empty = Garage();

  /// The active vehicle, falling back to the first one when [activeId] is
  /// stale or unset. Null only when the garage is empty.
  Vehicle? get active =>
      vehicles.where((v) => v.id == activeId).firstOrNull ??
      vehicles.firstOrNull;

  Garage setActive(String id) => vehicles.any((v) => v.id == id)
      ? Garage(vehicles: vehicles, activeId: id)
      : this;

  /// Replace by id, append when unknown. The first vehicle added to an empty
  /// garage becomes active.
  Garage upsert(Vehicle v) {
    final i = vehicles.indexWhere((e) => e.id == v.id);
    final next = [...vehicles];
    if (i >= 0) {
      next[i] = v;
    } else {
      next.add(v);
    }
    return Garage(vehicles: next, activeId: activeId.isEmpty ? v.id : activeId);
  }

  /// Deleting the active vehicle activates the next remaining one; deleting
  /// the last leaves an empty garage (spec M6 §4.3).
  Garage remove(String id) {
    final next = vehicles.where((v) => v.id != id).toList();
    final nextActive = next.any((v) => v.id == activeId)
        ? activeId
        : (next.firstOrNull?.id ?? '');
    return Garage(vehicles: next, activeId: nextActive);
  }

  Map<String, dynamic> toJson() => {
    'vehicles': vehicles.map((v) => v.toJson()).toList(),
    'activeId': activeId,
  };

  factory Garage.fromJson(Map<String, dynamic> j) {
    final raw = j['vehicles'];
    final vehicles = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(Vehicle.fromJson).toList()
        : <Vehicle>[];
    return Garage(
      vehicles: vehicles,
      activeId: j['activeId'] is String ? j['activeId'] as String : '',
    );
  }

  /// One-way migration from the M5 single profile (spec M6 §4.1). A profile
  /// with no vehicle info (name only) yields an EMPTY garage; an otherwise-
  /// populated profile becomes a single-vehicle garage.
  factory Garage.fromLegacyProfile(DriverProfile p) {
    final hasVehicle = [
      p.vehicleMake,
      p.vehicleModel,
      p.vehicleYear,
      p.licensePlate,
    ].any((s) => s.trim().isNotEmpty);
    if (!hasVehicle) return Garage.empty;
    final v = Vehicle(
      id: 'migrated-m5',
      make: p.vehicleMake,
      model: p.vehicleModel,
      year: p.vehicleYear,
      plate: p.licensePlate,
      colorValue: p.vehicleColor,
      bodyType: p.vehicleType,
    );
    return Garage(vehicles: [v], activeId: v.id);
  }
}
