import 'dart:convert';

import '../domain/app_currency.dart';
import '../domain/distance_unit.dart';
import '../domain/offer_summary.dart';
import '../domain/platform.dart';
import '../domain/rate_mode.dart';
import '../domain/verdict.dart';

/// Versioned, lossless CSV backup for the local offer history.
///
/// The human-readable columns make the file useful in a spreadsheet. The last
/// column is the authoritative serialized [OfferSummary], so importing the
/// file restores fields that a report normally cannot show (manual edits,
/// detected outcomes, and scoring snapshots included).
class HistoryBackupCodec {
  const HistoryBackupCodec._();

  static const version = 1;
  static const maxCharacters = 5 * 1024 * 1024;

  static const columns = <String>[
    'schema_version',
    'seen_at_utc',
    'app',
    'category',
    'queued',
    'orders',
    'items',
    'units',
    'verdict',
    'payout',
    'final_payout',
    'bonus',
    'pickup_km',
    'total_km',
    'minutes',
    'outcome',
    'outcome_is_manual',
    'detected_outcome',
    'scoring_snapshot_json',
    'record_json',
  ];

  static String encode(Iterable<OfferSummary> offers) {
    final out = StringBuffer()..writeln(columns.map(csvCell).join(','));
    for (final offer in offers) {
      final snapshot = offer.scoringSnapshot;
      out.writeln(
        <Object?>[
          version,
          offer.seenAt.toUtc().toIso8601String(),
          offer.platform.name,
          offer.category ?? '',
          offer.isQueued,
          offer.deliveryCount,
          offer.itemCount,
          offer.unitCount,
          offer.verdict.name,
          offer.payout,
          offer.finalPayout,
          offer.bonus,
          offer.pickupKm,
          offer.totalKm,
          offer.totalMinutes,
          offer.outcome.name,
          offer.outcomeIsManual,
          offer.detectedOutcome?.name ?? '',
          snapshot == null ? '' : jsonEncode(snapshot.toJson()),
          jsonEncode(offer.toJson()),
        ].map(csvCell).join(','),
      );
    }
    return out.toString();
  }

  static List<OfferSummary> decode(String source) {
    if (source.length > maxCharacters) {
      throw const HistoryBackupException('This backup is too large.');
    }
    final rows = _parseCsv(source.replaceFirst('\uFEFF', ''));
    if (rows.isEmpty || !_sameRow(rows.first, columns)) {
      throw const HistoryBackupException(
        'This is not a FoxyCo lossless CSV backup. Export a new backup first.',
      );
    }
    if (rows.length == 1) return const [];
    if (rows.length - 1 > 2000) {
      throw const HistoryBackupException(
        'A backup may contain at most 2,000 offers.',
      );
    }

    final result = <OfferSummary>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.length != columns.length) {
        throw HistoryBackupException(
          'Backup row $rowIndex has the wrong number of fields.',
        );
      }
      final versionValue = _int(row[0], rowIndex, 'schema_version');
      if (versionValue != version) {
        throw HistoryBackupException(
          versionValue > version
              ? 'This backup was created by a newer FoxyCo version. Update FoxyCo before restoring it.'
              : 'Backup row $rowIndex uses an unsupported version.',
        );
      }
      final record = _record(row[columns.length - 1], rowIndex);
      _validateRecord(record, rowIndex);
      result.add(OfferSummary.fromJson(record));
    }
    return result;
  }

  /// RFC 4180 escaping plus spreadsheet formula protection for display fields.
  static String csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (text.isNotEmpty && '=+-@'.contains(text[0])) text = "'$text";
    if (text.contains(RegExp(r'[",\r\n]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}

enum HistoryImportMode { merge, replace }

class HistoryImportResult {
  const HistoryImportResult({
    required this.imported,
    required this.added,
    required this.total,
  });

  final int imported;
  final int added;
  final int total;
}

class HistoryBackupException extends FormatException {
  const HistoryBackupException(super.message);
}

Map<String, dynamic> _record(String raw, int row) {
  try {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  } catch (_) {
    // Keep the user-facing error independent of imported text.
  }
  throw HistoryBackupException('Backup row $row contains invalid record data.');
}

void _validateRecord(Map<String, dynamic> record, int row) {
  String requiredString(String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw HistoryBackupException('Backup row $row is missing $key.');
    }
    return value;
  }

  double number(String key, {double min = 0}) {
    final value = record[key];
    if (value is! num || !value.toDouble().isFinite || value < min) {
      throw HistoryBackupException('Backup row $row contains an invalid $key.');
    }
    return value.toDouble();
  }

  int integer(String key, {int min = 0, int max = 100000}) {
    final value = record[key];
    if (value is! num ||
        value.toDouble() != value ||
        value < min ||
        value > max) {
      throw HistoryBackupException('Backup row $row contains an invalid $key.');
    }
    return value.toInt();
  }

  bool optionalBool(String key) {
    final value = record[key];
    if (value != null && value is! bool) {
      throw HistoryBackupException('Backup row $row contains an invalid $key.');
    }
    return value == true;
  }

  if (!GigPlatform.values.any((v) => v.name == requiredString('platform'))) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid platform.',
    );
  }
  if (!Verdict.values.any((v) => v.name == requiredString('verdict'))) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid verdict.',
    );
  }
  if (!OfferOutcome.values.any((v) => v.name == requiredString('outcome'))) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid outcome.',
    );
  }
  final detected = record['detectedOutcome'];
  if (detected != null &&
      (detected is! String ||
          !OfferOutcome.values.any((v) => v.name == detected))) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid detected outcome.',
    );
  }
  number('payout');
  final finalPayout = record['finalPayout'];
  if (finalPayout != null &&
      (finalPayout is! num ||
          !finalPayout.toDouble().isFinite ||
          finalPayout <= 0)) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid final payout.',
    );
  }
  number('bonus');
  final pickup = number('pickupKm');
  final total = number('totalKm');
  if (pickup > total) {
    throw HistoryBackupException(
      'Backup row $row has pickup distance above total distance.',
    );
  }
  number('totalMinutes');
  final seenAt = record['seenAt'];
  if (seenAt is! num || seenAt.toDouble() != seenAt || seenAt <= 0) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid timestamp.',
    );
  }
  final date = DateTime.fromMillisecondsSinceEpoch(seenAt.toInt(), isUtc: true);
  if (date.year < 2020 || date.year > 2100) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid timestamp.',
    );
  }
  final category = record['category'];
  if (category != null && (category is! String || category.length > 200)) {
    throw HistoryBackupException(
      'Backup row $row contains an invalid category.',
    );
  }
  optionalBool('outcomeIsManual');
  optionalBool('isQueued');
  integer('deliveryCount');
  integer('itemCount');
  integer('unitCount');

  final snapshot = record['scoringSnapshot'];
  if (snapshot != null) {
    if (snapshot is! Map) {
      throw HistoryBackupException(
        'Backup row $row contains an invalid scoring snapshot.',
      );
    }
    final s = Map<String, dynamic>.from(snapshot);
    final mode = s['rateMode'];
    final unit = s['distanceUnit'];
    final currency = s['currency'];
    if (!RateMode.values.any((v) => v.name == mode) ||
        !DistanceUnit.values.any((v) => v.name == unit) ||
        !AppCurrency.values.any((v) => v.name == currency)) {
      throw HistoryBackupException(
        'Backup row $row contains an invalid scoring snapshot.',
      );
    }
    for (final key in [
      'goodPerKm',
      'badPerKm',
      'goodPerHour',
      'badPerHour',
      'minimumPayout',
      'pickupNearKm',
    ]) {
      final value = s[key];
      if (value is! num || !value.toDouble().isFinite || value < 0) {
        throw HistoryBackupException(
          'Backup row $row contains an invalid scoring snapshot.',
        );
      }
    }
    if (s['minimumPayoutEnabled'] is! bool) {
      throw HistoryBackupException(
        'Backup row $row contains an invalid scoring snapshot.',
      );
    }
  }
}

bool _sameRow(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _int(String raw, int row, String field) {
  final value = int.tryParse(raw);
  if (value == null) {
    throw HistoryBackupException('Backup row $row contains an invalid $field.');
  }
  return value;
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var afterQuote = false;

  void finishField() {
    row.add(field.toString());
    field.clear();
    afterQuote = false;
  }

  void finishRow() {
    finishField();
    if (row.length != 1 || row.first.isNotEmpty) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          afterQuote = true;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (afterQuote) {
      if (char == ',') {
        finishField();
      } else if (char == '\n') {
        finishRow();
      } else if (char == '\r') {
        if (i + 1 < source.length && source[i + 1] == '\n') i++;
        finishRow();
      } else {
        throw const HistoryBackupException('Malformed CSV quoting.');
      }
    } else if (char == '"') {
      if (field.isNotEmpty) {
        throw const HistoryBackupException('Malformed CSV quoting.');
      }
      quoted = true;
    } else if (char == ',') {
      finishField();
    } else if (char == '\n') {
      finishRow();
    } else if (char == '\r') {
      if (i + 1 < source.length && source[i + 1] == '\n') i++;
      finishRow();
    } else {
      field.write(char);
    }
  }
  if (quoted) throw const HistoryBackupException('Malformed CSV quoting.');
  if (afterQuote || field.isNotEmpty || row.isNotEmpty) {
    finishRow();
  }
  return rows;
}
