import 'package:flutter/services.dart';

class HistoryBackupPlatform {
  const HistoryBackupPlatform([
    this._channel = const MethodChannel('foxyco/history_backup'),
  ]);

  final MethodChannel _channel;

  Future<Uint8List?> pickCsv() => _channel.invokeMethod<Uint8List>('pickCsv');

  Future<bool> saveCsv(Uint8List bytes, String filename) async =>
      (await _channel.invokeMethod<bool>('saveCsv', {
        'bytes': bytes,
        'filename': filename,
      })) ?? false;
}
