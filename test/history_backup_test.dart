import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/offer_summary.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/domain/verdict.dart';
import 'package:foxyco/services/history_backup.dart';

void main() {
  final offer = OfferSummary(
    platform: GigPlatform.lyft,
    verdict: Verdict.good,
    payout: 12.34,
    finalPayout: 13.01,
    bonus: 1.25,
    tip: 0.51,
    tollReimbursement: 2.25,
    pickupKm: 2.3,
    totalKm: 8.7,
    totalMinutes: 24,
    seenAt: DateTime.utc(2026, 8, 25, 18, 11),
    outcome: OfferOutcome.completed,
    outcomeIsManual: true,
    detectedOutcome: OfferOutcome.taken,
    category: 'text, with "quotes"\nand a formula =bad',
    isQueued: true,
    deliveryCount: 2,
    itemCount: 4,
    unitCount: 6,
  );

  test('round trips the canonical history record losslessly', () {
    final restored = HistoryBackupCodec.decode(
      HistoryBackupCodec.encode([offer]),
    ).single;
    expect(restored.toJson(), offer.toJson());
  });

  test('export filename includes local date and minute', () {
    expect(
      HistoryBackupCodec.filename(DateTime(2026, 8, 26, 17, 42)),
      'FoxyCo_History_20260826-1742.csv',
    );
  });

  test('round trips regular rides with omitted zero delivery counts', () {
    final ride = OfferSummary(
      platform: GigPlatform.uber,
      verdict: Verdict.ok,
      payout: 9.48,
      pickupKm: 2,
      totalKm: 11.5,
      seenAt: DateTime.utc(2026, 8, 26, 9, 4),
    );

    final restored = HistoryBackupCodec.decode(
      HistoryBackupCodec.encode([ride]),
    ).single;

    expect(restored.toJson(), ride.toJson());
  });

  test('rejects report CSV instead of guessing fields', () {
    expect(
      () => HistoryBackupCodec.decode('seen_at,app,outcome\n'),
      throwsA(isA<HistoryBackupException>()),
    );
  });

  test('accepts CRLF and protects formula-shaped text', () {
    final csv = HistoryBackupCodec.encode([offer]).replaceAll('\n', '\r\n');
    final restored = HistoryBackupCodec.decode(csv).single;
    expect(restored.category, offer.category);
    expect(HistoryBackupCodec.csvCell('=SUM(A1:A2)'), "'=SUM(A1:A2)");
  });

  test('explains newer backup versions', () {
    final csv = HistoryBackupCodec.encode([
      offer,
    ]).replaceFirst('1,2026', '2,2026');
    expect(
      () => HistoryBackupCodec.decode(csv),
      throwsA(
        predicate<HistoryBackupException>(
          (error) => error.message.contains('newer FoxyCo version'),
        ),
      ),
    );
  });
}
