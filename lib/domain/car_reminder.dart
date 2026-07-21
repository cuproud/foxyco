import 'package:flutter/material.dart';

/// One car-related date the driver wants to be reminded about — inspection,
/// insurance renewal, oil change, plate/registration renewal… Reminders are
/// surfaced in-app: a banner on Home once `date - leadDays` is reached, and a
/// countdown in Settings. Plain data, JSON-round-trippable.
class CarReminder {
  final String id; // millisecondsSinceEpoch at creation — unique enough
  final String title;
  final DateTime date; // the event date itself
  final int leadDays; // start reminding this many days before [date]
  final String note; // free text ("Canadian Tire, ask for Mike")

  const CarReminder({
    required this.id,
    required this.title,
    required this.date,
    required this.leadDays,
    this.note = '',
  });

  /// Days until the event, negative when past. Date-granular (times ignored).
  int daysLeft([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  /// Inside the reminder window (or overdue) — show the Home banner.
  bool isDue([DateTime? now]) => daysLeft(now) <= leadDays;

  CarReminder copyWith({
    String? title,
    DateTime? date,
    int? leadDays,
    String? note,
  }) => CarReminder(
    id: id,
    title: title ?? this.title,
    date: date ?? this.date,
    leadDays: leadDays ?? this.leadDays,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.millisecondsSinceEpoch,
    'leadDays': leadDays,
    'note': note,
  };

  factory CarReminder.fromJson(Map<String, dynamic> j) => CarReminder(
    id: (j['id'] as String?) ?? '',
    title: (j['title'] as String?) ?? 'Reminder',
    date: DateTime.fromMillisecondsSinceEpoch(
      (j['date'] as num?)?.toInt() ?? 0,
    ),
    leadDays: (j['leadDays'] as num?)?.toInt() ?? 30,
    note: (j['note'] as String?) ?? '',
  );
}

/// Preset titles drivers actually track (icon + label), plus lead-time
/// choices. Custom title is always available via the text field.
class ReminderPresets {
  const ReminderPresets._();

  static const titles = [
    (Icons.verified_outlined, 'Safety inspection'),
    (Icons.shield_outlined, 'Insurance renewal'),
    (Icons.oil_barrel_outlined, 'Oil change'),
    (Icons.badge_outlined, 'Registration / plates'),
    (Icons.tire_repair_outlined, 'Tire change'),
    (Icons.build_outlined, 'Maintenance service'),
  ];

  /// (days, label) lead-time options.
  static const leads = [
    (3, '3 days'),
    (7, '1 week'),
    (14, '2 weeks'),
    (30, '1 month'),
  ];
}
