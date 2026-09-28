/// A manually recorded cost associated with one vehicle.
class VehicleExpense {
  const VehicleExpense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });

  final String id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;

  Map<String, Object> toJson() => {
    'id': id,
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
  };

  factory VehicleExpense.fromJson(Map<String, dynamic> json) => VehicleExpense(
    id: json['id'] is String ? json['id'] as String : '',
    category: json['category'] is String
        ? json['category'] as String
        : 'Other miscellaneous',
    description: json['description'] is String
        ? json['description'] as String
        : '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    date: DateTime.fromMillisecondsSinceEpoch(
      (json['date'] as num?)?.toInt() ?? 0,
    ),
  );
}
